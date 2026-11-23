"""
Runs the addon's Lua outside the game, with a small stand-in for the WoW API (tests/wow_stub.lua).

    python tests/run_tests.py            # tests the Retail addon in this repository
    python tests/run_tests.py <folder>   # tests another addon folder that has the same Core/ and Panel/ (WoW Forever)

Needs `pip install lupa`. It checks logic and that no file calls an API the stub does not know; it cannot show how the
window looks, so the game still has the last word.
"""
import re
import sys
import traceback
from pathlib import Path

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent
STUB = ROOT / "tests" / "wow_stub.lua"

if len(sys.argv) > 1:
    ADDON_DIR = Path(sys.argv[1]).resolve()
else:
    ADDON_DIR = ROOT / "SuperNovaUI"

TOC = ADDON_DIR / f"{ADDON_DIR.name}.toc"
ADDON_NAME = ADDON_DIR.name
# the saved variable of the addon under test (the Forever addon has its own); tests write "SuperNovaUIDB" and it is renamed
DB_NAME = re.search(r'database = "(\w+)"', (ADDON_DIR / "Core" / "Config.lua").read_text(encoding="utf-8")).group(1)


def lua_files():
    files = []
    for line in TOC.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            files.append(ADDON_DIR / line.replace("\\", "/"))
    return files


def boot(installed=(), locale="enUS", saved=None, login=True, toc_version=None, before=None):
    """A fresh game: loads every file in .toc order, then fires ADDON_LOADED and (optionally) PLAYER_LOGIN."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(STUB.read_text(encoding="utf-8"))
    g = lua.globals()
    g.STUB.locale = locale
    if toc_version:
        g.STUB.tocVersion = toc_version
    for addon in installed:
        g.STUB.installed[addon] = True
    if saved:
        lua.execute(saved.replace("SuperNovaUIDB", DB_NAME))
    lua.execute("SN = {}")
    for path in lua_files():
        lua.execute(f'STUB.load("{path.as_posix()}", "{ADDON_NAME}", SN)')
    if before:
        lua.execute(before)  # e.g. register a module of the test's own
    lua.execute(f'SN.eventFrame.__scripts.OnEvent(SN.eventFrame, "ADDON_LOADED", "{ADDON_NAME}")')
    if login:
        lua.execute('SN.eventFrame.__scripts.OnEvent(SN.eventFrame, "PLAYER_LOGIN")')
    return lua


TESTS = []


def test(function):
    TESTS.append(function)
    return function


def has_module(lua, name):
    return lua.eval(f'SN.modules["{name}"] ~= nil')


# ---------------------------------------------------------------------------------------------------------------------


@test
def toc_files_exist():
    for path in lua_files():
        assert path.exists(), f"{TOC.name} lists a missing file: {path}"
    listed = {path.resolve() for path in lua_files()}
    on_disk = {path.resolve() for path in ADDON_DIR.rglob("*.lua")}
    assert listed == on_disk, f"files not in the .toc: {sorted(p.name for p in on_disk - listed)}"


@test
def boots_without_errors_and_registers_pages():
    lua = boot()
    for name in ("general", "profile", "debug"):
        assert has_module(lua, name), f"missing core page {name}"
    assert lua.eval("SN.db.firstRunDone") is False
    assert lua.eval('SN.db.ui.collapsed ~= nil')


@test
def modules_start_only_when_their_addon_is_installed():
    toggleable = list(boot().eval('SN:GetToggleableModules()').values()) if False else None
    lua = boot(installed=[], login=False)
    names = [n for n in lua.eval("(function() local t = {} for _, n in ipairs(SN:GetToggleableModules()) do t[#t+1] = n end return t end)()").values()]
    for name in names:
        required = lua.eval(f'SN:GetInfo("{name}").requiresAddon')
        if not required:
            continue  # modules that need no other addon (the macro by cooldown) are always available
        assert lua.eval(f'SN:IsModuleActive("{name}")') is False, f"{name} started without {required}"
        assert lua.eval(f'SN:GetModuleStatus("{name}")') == "missing"

    required_addons = [lua.eval(f'SN:GetInfo("{n}").requiresAddon') for n in names]
    lua = boot(installed=[a for a in required_addons if a], login=False)
    for name in names:
        recommended = lua.eval(f'SN:IsModuleRecommended("{name}")')
        assert lua.eval(f'SN:IsModuleActive("{name}")') is recommended, f"{name} should start only when it is recommended"
        if lua.eval(f'SN:GetInfo("{name}").requiresAddon') and not lua.eval(f'SN:GetInfo("{name}").isUseful'):
            assert recommended is True, f"{name} should be on by default when its addon is installed"


@test
def no_welcome_question_when_nothing_is_compatible():
    lua = boot(installed=[])
    if lua.eval("(function() local n = 0 for _, m in ipairs(SN:GetToggleableModules()) do if SN:IsModuleAvailable(m) then n = n + 1 end end return n end)()") == 0:
        assert lua.eval("SN.welcome") is None
        assert lua.eval("SN.db.firstRunDone") is False


@test
def welcome_question_yes_keeps_modules_on():
    probe = boot(login=False)
    names = [n for n in probe.eval("(function() local t = {} for _, n in ipairs(SN:GetToggleableModules()) do t[#t+1] = n end return t end)()").values()]
    required = [probe.eval(f'SN:GetInfo("{n}").requiresAddon') for n in names]
    if not names:
        return
    lua = boot(installed=[a for a in required if a])
    if lua.eval("#SN:GetRecommendedModules()") == 0:
        return  # nothing to offer (the WoW Forever addon has only the macro, which starts off)
    assert lua.eval("SN.welcome ~= nil and SN.welcome:IsShown()"), "the first-run question should appear"
    lua.execute('STUB.fire(STUB.findButton(SN:T("welcome_yes")), "OnClick")')
    assert lua.eval("SN.db.firstRunDone") is True
    assert lua.eval("SN.welcome:IsShown()") is False
    assert lua.eval("SN.panel == nil or not SN.panel:IsShown()")
    for name in names:
        assert lua.eval(f'SN:IsModuleEnabled("{name}")') is lua.eval(f'SN:IsModuleRecommended("{name}")')


DUP_MODULE = """
    SN:RegisterModuleDefaults("dup", { enabled = true })
    SN:RegisterModule("dup", { info = { category = "tools", kind = "feature", name = "Dup", desc = "Does what Other does",
        conflictsWith = { "OtherAddon" }, }, SetEnabled = function() end })
    SN:RegisterModuleDefaults("idle", { enabled = true })
    SN:RegisterModule("idle", { info = { category = "tools", kind = "feature", name = "Idle", desc = "Nothing to do",
        isUseful = function() return SN_IDLE_USEFUL == true end } })
"""


@test
def a_module_that_duplicates_another_addon_starts_off():
    lua = boot(installed=["OtherAddon"], before=DUP_MODULE)
    assert lua.eval('SN:IsModuleEnabled("dup")') is False
    assert lua.eval('SN:IsModuleActive("dup")') is False
    assert lua.eval('SN:IsModuleRecommended("dup")') is False
    lua = boot(installed=[], before=DUP_MODULE)
    assert lua.eval('SN:IsModuleEnabled("dup")') is True, "nothing else does the job, so it starts on"


@test
def an_addon_that_is_installed_but_switched_off_is_no_conflict():
    lua = boot(installed=["OtherAddon"], before=DUP_MODULE + 'STUB.addonDisabled = { OtherAddon = true }')
    assert lua.eval('SN:IsModuleEnabled("dup")') is True


@test
def a_module_with_nothing_to_do_starts_off():
    lua = boot(before=DUP_MODULE)
    assert lua.eval('SN:IsModuleEnabled("idle")') is False
    lua = boot(before=DUP_MODULE.replace("SN:RegisterModuleDefaults(\"idle\"", "SN_IDLE_USEFUL = true SN:RegisterModuleDefaults(\"idle\""))
    assert lua.eval('SN:IsModuleEnabled("idle")') is True


@test
def the_default_follows_the_situation_until_the_player_chooses():
    saved = "SuperNovaUIDB = { modules = { dup = { enabled = false } } }"
    lua = boot(installed=[], before=DUP_MODULE, saved=saved)
    assert lua.eval('SN:IsModuleEnabled("dup")') is True, "never switched by the player: it follows the recommendation"
    lua = boot(installed=["OtherAddon"], before=DUP_MODULE)
    lua.execute('SN:SetModuleEnabled("dup", true)')
    assert lua.eval('SN:GetModuleSettings("dup").chosen') is True
    assert lua.eval('(SN:GetModuleStatus("dup"))') == "warning", "turned on against a conflict: say so, but obey"
    saved = "SuperNovaUIDB = { modules = { dup = { enabled = true, chosen = true } } }"
    lua = boot(installed=["OtherAddon"], before=DUP_MODULE, saved=saved)
    assert lua.eval('SN:IsModuleEnabled("dup")') is True, "what the player chose is kept"
    assert lua.eval('SN:IsModuleActive("dup")') is True


@test
def settings_saved_before_the_policy_are_kept_as_the_players():
    saved = "SuperNovaUIDB = { firstRunDone = true, modules = { dup = { enabled = true } } }"
    lua = boot(installed=["OtherAddon"], before=DUP_MODULE, saved=saved)
    assert lua.eval('SN:IsModuleEnabled("dup")') is True
    assert lua.eval('SN:GetModuleSettings("dup").chosen') is True


@test
def welcome_question_yes_does_not_turn_on_what_starts_off():
    lua = boot(installed=["OtherAddon"], before=DUP_MODULE)
    lua.execute('SN.AnswerFirstRun(SN, true)')
    assert lua.eval('SN:IsModuleEnabled("dup")') is False
    assert lua.eval('SN:IsModuleEnabled("idle")') is False
    lines = lua.eval('table.concat((function() local t = {} for _, n in ipairs(SN:GetRecommendedModules()) do t[#t+1] = n end return t end)(), ",")')
    assert "dup" not in lines and "idle" not in lines


EXPLORATION_GAME = """
    SN.ExplorationData = { [1] = { { 10, 20, 30, 40, 0.2, 0.3, 5 }, { 50, 60, 70, 80, 0.6, 0.7, 6 } } }
    STUB.explored = { { offsetX = 10, offsetY = 20, textureWidth = 30, textureHeight = 40 } }
    C_Map = {
        GetBestMapForUnit = function() return 1 end,
        GetPlayerMapPosition = function() return { x = 0.5, y = 0.5 } end,
        GetAreaInfo = function(id) return "Area " .. id end,
    }
    C_MapExplorationInfo = { GetExploredMapTextures = function() return STUB.explored end }
"""


@test
def exploration_markers_cover_only_the_regions_without_a_discovery():
    lua = boot(before=EXPLORATION_GAME)
    assert lua.eval('SN:IsModuleEnabled("explore")') is True and lua.eval('SN:IsModuleActive("explore")') is True
    assert lua.eval('#SN.modules.explore:GetUndiscovered(1)') == 1
    assert lua.eval('SN.modules.explore:GetUndiscovered(1)[1][7]') == 6, "the region without a fog piece in the explored list"
    assert lua.eval('SN.modules.explore:GetUndiscovered(99)') is None, "a map the game gives no regions for"
    assert lua.eval('SN.modules.explore:GetAreaName(6)') == "Area 6"
    # discovering the second region: the list is read again after a few seconds, or at once on an exploration event
    lua.execute("STUB.explored[2] = { offsetX = 50, offsetY = 60, textureWidth = 70, textureHeight = 80 }")
    assert lua.eval('#SN.modules.explore:GetUndiscovered(1)') == 1, "the read is reused for a moment"
    lua.execute("STUB.now = STUB.now + 10")
    assert lua.eval('#SN.modules.explore:GetUndiscovered(1)') == 0


@test
def exploration_markers_start_off_where_they_cannot_work_or_would_duplicate_leatrix_maps():
    assert boot().eval('SN:IsModuleEnabled("explore")') is False, "no map API (stand-in game): nothing to do"
    lua = boot(installed=["Leatrix_Maps"], before=EXPLORATION_GAME)
    assert lua.eval('SN:IsModuleEnabled("explore")') is False
    assert lua.eval('SN:IsModuleActive("explore")') is False
    lua.execute('SN:SetModuleEnabled("explore", true)')
    assert lua.eval('SN:IsModuleActive("explore")') is True, "the player can still turn it on"
    assert lua.eval('SN:GetModuleSettings("explore").chosen') is True


@test
def exploration_marker_icon_exists_and_the_module_points_to_it():
    import struct
    lua = boot(before=EXPLORATION_GAME)
    path = ADDON_DIR / "Media" / "Icons" / "Unexplored.tga"
    assert path.exists(), "the marker icon is missing"
    header = path.read_bytes()[:18]
    width, height, bits = struct.unpack("<HHB", header[12:17])
    assert (width & (width - 1)) == 0 and (height & (height - 1)) == 0 and bits == 32, "a power-of-two 32 bit texture"
    assert (ADDON_DIR / "Media" / "Icons" / "SuperNovaUI.tga").exists()
    assert lua.eval('(SN.config.icon:gsub("SuperNovaUI$", "Unexplored"))').endswith("\\Icons\\Unexplored")


CONVERGENCE_FILE = ADDON_DIR / "Modules" / "Forever" / "Convergence.lua"
CONVERGENCE_GAME = """
    C_Map = {
        GetBestMapForUnit = function() return 1411 end,
        GetPlayerMapPosition = function() return { x = 0.5, y = 0.5 } end,
        GetMapInfo = function() return { name = "Durotar" } end,
    }
    UnitRace = function() return "Windshaper Skyborne", "Skyborne", STUB.raceID or 96 end
"""

if CONVERGENCE_FILE.exists():  # the Elemental Convergence markers exist only in the WoW Forever addon

    @test
    def convergence_markers_know_every_zone_and_start_on_only_for_a_windshaper():
        lua = boot(before=CONVERGENCE_GAME)
        assert lua.eval("#SN.ConvergenceData[1411]") == 4, "Durotar has two convergences, as two x,y pairs"
        assert lua.eval("SN.ConvergenceData[1411][1]") == 0.451
        assert lua.eval('SN:IsModuleEnabled("converge")') is True and lua.eval('SN:IsModuleActive("converge")') is True
        points = lua.eval("(function() local n = 0 for _, list in pairs(SN.ConvergenceData) do n = n + #list / 2 end return n end)()")
        assert points == 417, points
        assert lua.eval("(function() local n = 0 for _ in pairs(SN.ConvergenceData) do n = n + 1 end return n end)()") == 41
        other = boot(before=CONVERGENCE_GAME.replace("STUB.raceID or 96", "5"))
        assert other.eval('SN:IsModuleEnabled("converge")') is False, "any other race has no use for it"
        other.execute('SN:SetModuleEnabled("converge", true)')
        assert other.eval('SN:IsModuleActive("converge")') is True, "the player can still turn it on"
        assert boot().eval('SN:IsModuleEnabled("converge")') is False, "no map API: nothing to do"

    @test
    def convergence_points_are_inside_their_maps_and_the_icon_exists():
        import struct
        lua = boot(before=CONVERGENCE_GAME)
        bad = lua.eval("(function() local n = 0 for _, list in pairs(SN.ConvergenceData) do for _, v in ipairs(list) do if v < 0 or v > 1 then n = n + 1 end end end return n end)()")
        assert bad == 0
        path = ADDON_DIR / "Media" / "Icons" / "Convergence.tga"
        assert path.exists(), "the convergence icon is missing"
        width, height, bits = struct.unpack("<HHB", path.read_bytes()[12:17])
        assert (width, height, bits) == (32, 32, 32)
        assert lua.eval('(SN.config.icon:gsub("SuperNovaUI$", "Convergence"))').endswith("\Icons\Convergence")

    @test
    def convergence_markers_use_the_partner_addons_list_when_it_is_installed():
        mod = "SN.modules.converge"
        own = boot(before=CONVERGENCE_GAME)
        assert own.eval(f"#{mod}:GetPoints(1411)") == 4, "without the partner, our own list"
        partner = boot(before=CONVERGENCE_GAME + """
            SLLCM_GetNodes = function(faction) STUB.askedFaction = faction return { [1411] = { { 0.1, 0.2 }, { 0.3, 0.4 }, { 0.5, 0.6 } } } end
        """)
        assert partner.eval(f"#{mod}:GetPoints(1411)") == 6, "the partner's three points, as a flat list"
        assert partner.eval(f"{mod}:GetPoints(1411)[3]") == 0.3
        assert partner.eval("STUB.askedFaction") == "Horde"
        assert partner.eval(f"#{mod}:GetPoints(1412)") == own.eval(f"#{mod}:GetPoints(1412)"), "a zone it lacks keeps ours"
        broken = boot(before=CONVERGENCE_GAME + "SLLCM_GetNodes = function() error('boom') end")
        assert broken.eval(f"#{mod}:GetPoints(1411)") == 4, "a failing partner never breaks the module"


@test
def exploration_markers_follow_the_direction_the_minimap_faces():
    lua = boot(before=EXPLORATION_GAME)
    project = "SN.modules.explore.Project"

    def at(east, north, rotates, facing):
        x, y = lua.eval(f"{project}({east}, {north}, {rotates}, {facing})")
        return round(x, 6) + 0.0, round(y, 6) + 0.0

    assert at(100, 50, "false", 1.234) == (100.0, 50.0), "a fixed minimap keeps north at the top"
    assert at(100, 50, "true", 0) == (100.0, 50.0)
    assert at(-1, 0, "true", "math.pi / 2") == (0.0, 1.0), "facing west: a point to the west is straight ahead"
    assert at(0, 1, "true", "math.pi") == (0.0, -1.0), "facing south: a point to the north is behind"
    assert at(1, 0, "true", "-math.pi / 2") == (0.0, 1.0), "facing east: a point to the east is straight ahead"


@test
def welcome_question_no_turns_everything_off_and_opens_the_panel():
    probe = boot(login=False)
    names = [n for n in probe.eval("(function() local t = {} for _, n in ipairs(SN:GetToggleableModules()) do t[#t+1] = n end return t end)()").values()]
    required = [probe.eval(f'SN:GetInfo("{n}").requiresAddon') for n in names]
    if not names:
        return
    lua = boot(installed=[a for a in required if a])
    if lua.eval("SN.welcome == nil"):
        lua.execute("SN:AnswerFirstRun(false)")
    else:
        lua.execute('STUB.fire(STUB.findButton(SN:T("welcome_no")), "OnClick")')
    assert lua.eval("SN.db.firstRunDone") is True
    for name in names:
        assert lua.eval(f'SN:IsModuleEnabled("{name}")') is False
    assert lua.eval("SN.panel:IsShown()"), "the panel should open so the player can choose"
    # only modules that cannot stop on the fly (no SetEnabled) need a reload
    needs_reload = lua.eval("(function() for _, n in ipairs(SN:GetToggleableModules()) do if SN.modules[n].SetEnabled == nil and SN:IsModuleAvailable(n) then return true end end return false end)()")
    assert lua.eval("SN:HasPendingReload()") == needs_reload, "modules that were running need a reload to stop"
    assert lua.eval("SN.panel.banner:IsShown()") == needs_reload


@test
def question_is_not_asked_twice():
    probe = boot(login=False)
    names = [n for n in probe.eval("(function() local t = {} for _, n in ipairs(SN:GetToggleableModules()) do t[#t+1] = n end return t end)()").values()]
    required = [probe.eval(f'SN:GetInfo("{n}").requiresAddon') for n in names]
    if not names:
        return
    lua = boot(installed=[a for a in required if a], saved="SuperNovaUIDB = { firstRunDone = true }")
    assert lua.eval("SN.welcome") is None


@test
def enable_and_disable_all():
    lua = boot()
    lua.execute("SN:SetAllEnabled(false)")
    assert lua.eval("(SN:CountEnabledModules())") == 0
    lua.execute("SN:SetAllEnabled(true)")
    enabled, total = lua.eval("SN:CountEnabledModules()")
    assert enabled == total


@test
def module_that_cannot_stop_live_asks_for_reload_but_a_live_one_does_not():
    lua = boot()
    lua.execute("""
        local live = { Initialize = function() end, SetEnabled = function(self, on) self.on = on end,
            info = { category = "tools", kind = "feature", name = "Live", desc = "" } }
        SN:RegisterModuleDefaults("live", { enabled = true })
        SN:RegisterModule("live", live)
        SN.db.modules.live = { enabled = true }
        SN:ActivateModule("live")
    """)
    assert lua.eval('SN:SetModuleEnabled("live", false)') is True
    assert lua.eval("SN:HasPendingReload()") is False
    assert lua.eval('SN:IsModuleActive("live")') is False
    assert lua.eval('SN:SetModuleEnabled("live", true)') is True
    assert lua.eval('SN:IsModuleActive("live")') is True


@test
def option_validation():
    lua = boot()
    lua.execute("""
        SN:RegisterModuleDefaults("opts", { enabled = true })
        SN:RegisterModule("opts", { info = { category = "tools", kind = "feature", name = "Opts", desc = "",
            options = {
                { type = "toggle", key = "t", text = "t", default = true },
                { type = "choice", key = "c", text = "c", default = "a", values = { { value = "a", text = "A" }, { value = "b", text = "B" } } },
                { type = "slider", key = "s", text = "s", min = 0, max = 10, step = 2, default = 4 },
            } } })
        SN.db.modules.opts = { enabled = true }
    """)
    assert lua.eval('SN:GetOption("opts", "t")') is True
    assert lua.eval('SN:SetOption("opts", "t", "yes")') is False
    assert lua.eval('SN:SetOption("opts", "c", "z")') is False
    assert lua.eval('SN:SetOption("opts", "c", "b")') is True
    assert lua.eval('SN:SetOption("opts", "s", 99)') is True and lua.eval('SN:GetOption("opts", "s")') == 10
    assert lua.eval('SN:SetOption("opts", "s", 5)') is True and lua.eval('SN:GetOption("opts", "s")') in (4, 6)
    assert lua.eval('SN:SetOption("opts", "s", 0/0)') is False
    assert lua.eval('SN:SetOption("opts", "nope", true)') is False
    lua.execute('SN:ResetModule("opts")')
    assert lua.eval('SN:GetOption("opts", "c")') == "a" and lua.eval('SN:GetOption("opts", "s")') == 4


@test
def profile_round_trip_and_rejections():
    lua = boot()
    lua.execute("""
        SN:RegisterModuleDefaults("opts", { enabled = true })
        SN:RegisterModule("opts", { info = { category = "tools", kind = "feature", name = "Opts", desc = "",
            options = { { type = "slider", key = "s", text = "s", min = 0, max = 10, step = 1, default = 4 } } } })
        SN.db.modules.opts = { enabled = true }
        SN:SetOption("opts", "s", 7)
        SN:SetModuleEnabled("opts", false)
        EXPORTED = SN:ExportProfile()
    """)
    exported = lua.eval("EXPORTED")
    assert exported.startswith("SNUI1:"), exported

    # change things, then import the export: it must come back
    lua.execute('SN:SetOption("opts", "s", 1); SN:SetModuleEnabled("opts", true)')
    result = lua.eval('(function() local ok, data = SN:ReadProfile(EXPORTED); assert(ok, data); local plan = SN:PlanProfileImport(data); SN:ApplyProfileImport(plan); return #plan end)()')
    assert result == 1
    assert lua.eval('SN:GetOption("opts", "s")') == 7
    assert lua.eval('SN:IsModuleEnabled("opts")') is False
    # importing the same thing again changes nothing
    assert lua.eval('(function() local _, data = SN:ReadProfile(EXPORTED); return #SN:PlanProfileImport(data) end)()') == 0
    # whitespace and line breaks pasted around the text are fine
    assert lua.eval('(SN:ReadProfile("  " .. EXPORTED:sub(1, 20) .. "\\n" .. EXPORTED:sub(21) .. "\\n"))') is True

    cases = {
        "": "profile_empty",
        "hello": "profile_err_format",
        "SNUI9:00000000:e30=": "profile_err_version",
        "SNUI1:00000000:" + exported.split(":", 2)[2]: "profile_err_checksum",
        "SNUI1:" + exported.split(":")[1] + ":" + exported.split(":", 2)[2][:-8]: "profile_err_checksum",
    }
    for text, expected in cases.items():
        ok, key = lua.eval(f'(function() local ok, key = SN:ReadProfile({lua_string(text)}); return ok, key end)()')
        assert ok is False and key == expected, f"{text!r}: {ok} {key}"


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


@test
def profile_import_ignores_unknown_modules_and_invalid_values():
    lua = boot()
    lua.execute("""
        SN:RegisterModuleDefaults("opts", { enabled = true })
        SN:RegisterModule("opts", { info = { category = "tools", kind = "feature", name = "Opts", desc = "",
            options = { { type = "slider", key = "s", text = "s", min = 0, max = 10, step = 1, default = 4 } } } })
        SN.db.modules.opts = { enabled = true }
        local function pack(tbl)
            local payload = SN:Serialize(tbl)
            local sum = 5381
            for i = 1, #payload do sum = (sum * 33 + payload:byte(i)) % 4294967296 end
            return "SNUI1:" .. string.format("%08x", sum) .. ":" .. SN:Base64Encode(payload)
        end
        local evil = { format = 1, family = SN.config.family, flavor = "retail", modules = {
            opts = { enabled = "yes", s = 9999, unknown = true, ["__index"] = "x" },
            ghost = { enabled = false },
            general = { enabled = false },
        } }
        local ok, data = SN:ReadProfile(pack(evil))
        assert(ok, data)
        PLAN = SN:PlanProfileImport(data)
        local other = { format = 1, family = "SomethingElse", modules = {} }
        local ok2, key2 = SN:ReadProfile(pack(other))
        OTHER_OK, OTHER_KEY = ok2, key2
    """)
    # opts: "enabled" is a string so ignored, s is clamped to 10, nothing else gets in; ghost/general do not exist as toggleable
    assert lua.eval("#PLAN") == 1
    assert lua.eval("PLAN[1].module") == "opts"
    assert lua.eval("PLAN[1].enabled") is None
    assert lua.eval("PLAN[1].options.s") == 10
    assert lua.eval("OTHER_OK") is False and lua.eval("OTHER_KEY") == "profile_err_family"


@test
def deserializer_survives_hostile_input():
    lua = boot()
    hostile = [
        "{" * 200, '{"a":' * 50, '"unterminated', "{1:2}", '{"a" "b"}', "function() end", "print(1)", '{"a":nil}',
        "x" * 100000, '{"a":1e999}', '{"a":-}', '{"a":1}{"b":2}', "\x00\x01\x02", '{"\\q":1}',
    ]
    for text in hostile:
        ok = lua.eval(f'(function() local ok = SN:Deserialize({lua_string(text)}); return ok end)()')
        assert ok in (True, False)
    assert lua.eval('(SN:Deserialize("{\\"a\\":{\\"b\\":[1]}}"))') is False
    assert lua.eval('(SN:Deserialize("{\\"a\\":{\\"b\\":2}}"))') is True


@test
def base64_round_trip():
    lua = boot()
    for sample in ["", "a", "ab", "abc", "abcd", "ñ ç é ~ \x00\xff binary", "x" * 1000]:
        out = lua.eval(f'(function() local s = {lua_string(sample)}; return SN:Base64Decode(SN:Base64Encode(s)) == s end)()')
        assert out is True, repr(sample)
    assert lua.eval('SN:Base64Decode("abc")') is None
    assert lua.eval('SN:Base64Decode("ab$d")') is None


@test
def panel_opens_lists_categories_and_every_page_builds():
    lua = boot(installed=["PremadeGroupsFilter", "Rematch"])
    lua.execute("SN:OpenPanel()")
    assert lua.eval("SN.panel:IsShown()")
    tree = lua.eval("""(function() local t = {} for _, c in ipairs(SN:GetModuleTree()) do t[#t+1] = c.id .. ":" .. table.concat(c.modules, ",") end return table.concat(t, ";") end)()""")
    assert tree.startswith("general:general,profile,debug"), tree
    for name in lua.eval("(function() local t = {} for _, n in ipairs(SN.moduleOrder) do t[#t+1] = n end return table.concat(t, ' ') end)()").split():
        lua.execute(f'SN:SelectModule("{name}")')
        assert lua.eval(f'SN.panel.selected == "{name}"')
    lua.execute("SN:RefreshPanel()")


@test
def search_filters_and_empty_state():
    lua = boot(installed=["PremadeGroupsFilter", "Rematch"])
    lua.execute("SN:OpenPanel()")
    all_modules = lua.eval("#SN:GetModuleTree()")
    assert lua.eval('#SN:GetModuleTree("zzzz-no-such-module")') == 0
    lua.execute('SN.panel.search.__text = "zzzz-no-such-module"; STUB.fire(SN.panel.search, "OnTextChanged")')
    assert lua.eval("SN.panel.empty:IsShown()")
    lua.execute('SN.panel.search.__text = ""; STUB.fire(SN.panel.search, "OnTextChanged")')
    assert lua.eval("SN.panel.empty:IsShown()") is False
    assert lua.eval("#SN:GetModuleTree()") == all_modules
    # collapsing a category hides its modules from the list but not from the tree
    lua.execute('STUB.fire(STUB.findButton("-  " .. SN:T("cat_general")), "OnClick")')
    assert lua.eval("SN.db.ui.collapsed.general") is True


@test
def portuguese_text_and_language_switch():
    lua = boot(locale="ptBR")
    assert lua.eval('SN:T("enable_all")') == "Ativar todos"
    lua.execute("SN:OpenPanel()")
    lua.execute('SN.db.language = "enUS"; SN:UpdateLocale("enUS"); SN:RebuildPanel()')
    assert lua.eval('SN:T("enable_all")') == "Enable all"
    lua.execute('SN.db.language = "auto"; SN:UpdateLocale("auto")')
    assert lua.eval("SN.localeKey") == "ptBR"
    assert lua.eval('SN:Loc({ enUS = "a", ptBR = "b" })') == "b"
    assert lua.eval('SN:Loc({ enUS = "a" })') == "a"
    # every English string has a Portuguese one, and the other way round
    missing = lua.eval("""(function()
        local out = {}
        for key in pairs(SN.strings.enUS) do if not SN.strings.ptBR[key] then out[#out+1] = "pt:" .. key end end
        for key in pairs(SN.strings.ptBR) do if not SN.strings.enUS[key] then out[#out+1] = "en:" .. key end end
        return table.concat(out, ",")
    end)()""")
    assert missing == "", missing


@test
def slash_commands():
    lua = boot(installed=["PremadeGroupsFilter", "Rematch"])
    lua.execute('SN:HandleSlashCommand("")')
    assert lua.eval("SN.panel:IsShown()")
    lua.execute('SN:HandleSlashCommand("")')
    assert lua.eval("SN.panel:IsShown()") is False
    lua.execute('SN:HandleSlashCommand("help"); SN:HandleSlashCommand("status"); SN:HandleSlashCommand("nonsense")')
    printed = "\n".join(lua.eval("STUB.printed").values())
    assert "/snui" in printed and "unknown command" in printed


@test
def disabled_module_stays_off_after_restart():
    probe = boot(login=False)
    names = [n for n in probe.eval("(function() local t = {} for _, n in ipairs(SN:GetToggleableModules()) do t[#t+1] = n end return t end)()").values()]
    if not names:
        return
    name = names[0]
    required = probe.eval(f'SN:GetInfo("{name}").requiresAddon')
    installed = [required] if required else []
    lua = boot(installed=installed, saved=f'SuperNovaUIDB = {{ firstRunDone = true, modules = {{ {name} = {{ enabled = false }} }} }}')
    assert lua.eval(f'SN:IsModuleActive("{name}")') is False
    assert lua.eval(f'SN:GetModuleStatus("{name}")') == "disabled"


# Retail modules (skipped for addons that do not have them) --------------------------------------------------------


def retail_only(lua):
    return has_module(lua, "pgf") and has_module(lua, "rematch")


PGF_FAKE = """
    PremadeGroupsFilter = { Debug = { L = {},
        PutSearchResultMemberInfos = function(id, info, env) env.hasmyspec = true end,
        HasRemainingSlotsForLocalPlayerPartyRoles = function() return true end } }
"""


@test
def pgf_is_a_live_toggle_that_only_changes_the_answer_while_on():
    if not retail_only(boot(login=False)):
        return
    lua = boot(installed=["PremadeGroupsFilter"], saved=PGF_FAKE, login=False)
    lua.execute("""
        local pgf = PremadeGroupsFilter.Debug
        function ASK() local env = {}; pgf.PutSearchResultMemberInfos(1, {}, env); return pgf.HasRemainingSlotsForLocalPlayerPartyRoles() end
    """)
    assert lua.eval("ASK()") is False, "with the tweak on, a group that has my spec does not fit"
    assert "class and specialization" in lua.eval('PremadeGroupsFilter.Debug.L["dialog.partyfit.tooltip"]')
    assert lua.eval('SN:SetModuleEnabled("pgf", false)') is True, "PGF can stop on the fly"
    assert lua.eval("SN:HasPendingReload()") is False
    assert lua.eval("ASK()") is True, "with the tweak off, PGF's own answer comes back"
    assert lua.eval('PremadeGroupsFilter.Debug.L["dialog.partyfit.tooltip"]') is None
    assert lua.eval('SN:SetModuleEnabled("pgf", true)') is True
    assert lua.eval("ASK()") is False
    assert lua.eval('(SN:GetModuleStatus("pgf"))') == "active"


@test
def pgf_status_warns_when_installed_but_not_hooked():
    if not retail_only(boot(login=False)):
        return
    lua = boot(installed=["PremadeGroupsFilter"], saved="PremadeGroupsFilter = {}", login=False)
    status, detail = lua.eval('SN:GetModuleStatus("pgf")')
    assert status == "warning" and "not hooked" in detail["enUS"]


@test
def rematch_is_a_live_toggle():
    if not retail_only(boot(login=False)):
        return
    fake = """
        Rematch = { localization = { ["%s (npc id %d)"] = "%s (npc %d)" },
            targetInfo = { GetNpcName = function() error("secret string value") end } }
    """
    lua = boot(installed=["Rematch"], saved=fake, login=False)
    assert lua.eval("Rematch.targetInfo:GetNpcName(5)") == "Unknown (npc 5)"
    assert lua.eval('SN:SetModuleEnabled("rematch", false)') is True
    assert lua.eval("(pcall(Rematch.targetInfo.GetNpcName, Rematch.targetInfo, 5))") is False
    assert lua.eval('SN:SetModuleEnabled("rematch", true)') is True
    assert lua.eval("Rematch.targetInfo:GetNpcName(5)") == "Unknown (npc 5)"


@test
def shims_module_saves_the_choice_for_the_companion_and_asks_for_a_reload():
    if not has_module(boot(login=False), "shims"):
        return
    fake = 'SuperNovaUICompat = { GetShimStates = function() return { { name = "a", description = "A", active = true }, { name = "b", description = "B", active = false } } end }'
    lua = boot(installed=["!SuperNovaUI_Compat"], saved=fake, login=False)
    status, detail = lua.eval('SN:GetModuleStatus("shims")')
    assert status == "active" and detail["enUS"] == "1 of 2 restored", (status, detail)
    assert lua.eval('SN:SetModuleEnabled("shims", false)') is False
    assert lua.eval("SuperNovaUICompatDB.disabled") is True
    assert lua.eval('(SN:GetModuleStatus("shims"))') == "pending"
    assert lua.eval('SN:SetModuleEnabled("shims", true)') is True
    assert lua.eval("SuperNovaUICompatDB.disabled") is None
    assert lua.eval("SN:HasPendingReload()") is False
    # the module lists what it restores, and without the companion it is "missing"
    assert lua.eval("#SN:GetInfo('shims').options") == 3
    assert lua.eval('(SN:GetModuleStatus("shims"))') == "active"
    assert boot(installed=[], login=False).eval('(SN:GetModuleStatus("shims"))') == "missing"


@test
def companion_skips_the_shims_when_turned_off():
    companion = ROOT / "!SuperNovaUI_Compat" / "Shims.lua"
    if not companion.exists() or ADDON_DIR != ROOT / "SuperNovaUI":
        return
    for turned_off in (False, True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(STUB.read_text(encoding="utf-8"))
        lua.execute("C_Item = {}; Enum = nil")
        if turned_off:
            lua.execute("SuperNovaUICompatDB = { disabled = true }")
        lua.execute(f'STUB.load("{companion.as_posix()}", "!SuperNovaUI_Compat", {{}})')
        states = lua.eval("SuperNovaUICompat:GetShimStates()")
        mouse = lua.eval("MouseIsOver ~= nil")
        assert mouse is (not turned_off), f"MouseIsOver defined={mouse} with turned_off={turned_off}"
        assert all(s["disabled"] is turned_off for s in states.values())
        assert all(s["active"] is False for s in states.values()) or not turned_off


@test
def compat_page_replaces_the_old_window():
    if not has_module(boot(login=False), "compat"):
        return
    assert not (ADDON_DIR / "Modules" / "CompatPanel.lua").exists()
    lua = boot(installed=["Rematch", "tdBattlePetScript"])
    lua.execute('SN:HandleSlashCommand("compat")')
    assert lua.eval("SN.panel:IsShown()") and lua.eval('SN.panel.selected') == "compat"
    page = lua.eval("SN.panel.currentPage.flow")
    assert page is not None
    lua.execute('SN:HandleSlashCommand("compat status")')
    printed = "\n".join(lua.eval("STUB.printed").values())
    assert "tdBattlePetScript" in printed
    assert "/snui compat" in "\n".join(lua.eval("(function() local t = {} for _, n in ipairs(SN.moduleOrder) do for _, l in ipairs((SN:GetInfo(n) or {}).help or {}) do t[#t+1] = l end end return t end)()").values())


# Polish: tooltips, window position, keyboard ----------------------------------------------------------------------


@test
def tree_rows_have_tooltips_and_headers_do_not():
    lua = boot(installed=["PremadeGroupsFilter", "Rematch"])
    lua.execute("SN:OpenPanel()")
    lua.execute('STUB.fire(STUB.findButton(SN:GetModuleDisplayName("profile")), "OnEnter")')
    assert lua.eval("GameTooltip.__title") == "Profile"
    assert lua.eval("#GameTooltip.__lines") >= 2
    lua.execute('STUB.fire(STUB.findButton(SN:GetModuleDisplayName("profile")), "OnLeave")')
    assert lua.eval("GameTooltip:IsShown()") is False
    # a header reuses a row that may have had a tooltip: it must be cleared
    lua.execute('GameTooltip.__title = "none"; STUB.fire(STUB.findButton("-  " .. SN:T("cat_general")), "OnEnter")')
    assert lua.eval("GameTooltip.__title") == "none"


@test
def tooltip_of_a_fix_module_names_the_required_addon():
    lua = boot(installed=["Rematch"])
    if not has_module(lua, "rematch"):
        return
    lines = "\n".join(lua.eval('SN:GetModuleTooltipLines("rematch")').values())
    assert "Rematch (installed)" in lines and "Addon fix" in lines
    lines = "\n".join(boot(installed=[]).eval('SN:GetModuleTooltipLines("rematch")').values())
    assert "not installed" in lines


@test
def window_position_is_saved_restored_and_reset():
    lua = boot()
    lua.execute("SN:OpenPanel()")
    assert lua.eval("(SN.panel:GetPoint())") == "CENTER"
    lua.execute('SN.panel:ClearAllPoints(); SN.panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -60); STUB.fire(SN.panel, "OnDragStop")')
    assert lua.eval("SN.db.ui.position.point") == "TOPLEFT"
    assert lua.eval("SN.db.ui.position.x") == 40 and lua.eval("SN.db.ui.position.y") == -60
    saved = "SuperNovaUIDB = { ui = { collapsed = {}, position = { point = 'BOTTOMRIGHT', relativePoint = 'BOTTOMRIGHT', x = -10, y = 20 } } }"
    again = boot(saved=saved)
    again.execute("SN:OpenPanel()")
    assert again.eval("(SN.panel:GetPoint())") == "BOTTOMRIGHT"
    again.execute("SN:ResetPanelPosition()")
    assert again.eval("SN.db.ui.position") is None
    assert again.eval("(SN.panel:GetPoint())") == "CENTER"
    # a damaged saved position falls back to the centre
    broken = boot(saved="SuperNovaUIDB = { ui = { collapsed = {}, position = 'oops' } }")
    broken.execute("SN:OpenPanel()")
    assert broken.eval("(SN.panel:GetPoint())") == "CENTER"


@test
def arrow_keys_move_through_the_visible_modules():
    lua = boot(installed=["PremadeGroupsFilter", "Rematch"])
    lua.execute("SN:OpenPanel()")
    visible = list(lua.eval('(function() local t = {} for _, n in ipairs(SN.panel.visible) do t[#t+1] = n end return t end)()').values())
    assert visible[:3] == ["general", "profile", "debug"], visible
    assert lua.eval("SN.panel.selected") == "general"
    lua.execute('STUB.fire(SN.panel, "OnKeyDown", "DOWN")')
    assert lua.eval("SN.panel.selected") == "profile"
    assert lua.eval("SN.panel.__propagate") is False, "a handled key must not reach the game"
    lua.execute('STUB.fire(SN.panel, "OnKeyDown", "UP"); STUB.fire(SN.panel, "OnKeyDown", "UP")')
    assert lua.eval("SN.panel.selected") == "general", "stops at the first module"
    for _ in range(len(visible) + 3):
        lua.execute('STUB.fire(SN.panel, "OnKeyDown", "DOWN")')
    assert lua.eval("SN.panel.selected") == visible[-1], "stops at the last module"
    lua.execute('STUB.fire(SN.panel, "OnKeyDown", "W")')
    assert lua.eval("SN.panel.__propagate") is True, "other keys keep working in the game"
    # arrows in the search box work too
    lua.execute('STUB.fire(SN.panel.search, "OnArrowPressed", "Up")')
    assert lua.eval("SN.panel.selected") == visible[-2]


@test
def ctrl_f_focuses_the_search_box_and_combat_leaves_input_alone():
    lua = boot()
    lua.execute("SN:OpenPanel()")
    lua.execute('STUB.ctrl = true; STUB.fire(SN.panel, "OnKeyDown", "F")')
    assert lua.eval("SN.panel.__propagate") is False
    lua.execute("STUB.ctrl = false; SN.panel.__propagate = 'untouched'; STUB.inCombat = true")
    lua.execute('STUB.fire(SN.panel, "OnKeyDown", "DOWN")')
    assert lua.eval("SN.panel.__propagate") == "untouched", "never touch the protected propagation flag in combat"


@test
def toggle_tooltip_shows_the_option_description():
    lua = boot()
    lua.execute("""
        SN:RegisterModuleDefaults("tip", { enabled = true })
        SN:RegisterModule("tip", { info = { category = "tools", kind = "feature", name = "Tip", desc = "About tip",
            options = { { type = "toggle", key = "t", text = "Do it", desc = "Does the thing", default = true } } } })
        SN.db.modules.tip = { enabled = true }
        SN:OpenPanel("tip")
    """)
    lua.execute('STUB.fire(STUB.findButton("Do it") or SN.panel.currentPage.flow.parent, "OnEnter")')
    # the check box is not a flat button: find it through the page
    found = lua.eval("""(function()
        for _, frame in ipairs(STUB.frames) do
            if frame.label and frame.label.__text == "Do it" and frame.tooltip then
                local title, lines = frame.tooltip()
                return title .. "|" .. lines[1]
            end
        end
    end)()""")
    assert found == "Do it|Does the thing", found


# --- Macro by cooldown ---------------------------------------------------------------------------------------------

MACRO_SETUP = """
    SN:SetModuleEnabled("macro", true) -- the player turns it on
    STUB.spellNames[1259686] = "Sky Vision"
    STUB.spellNames[1850] = "Dash"
    STUB.spellNames[768] = "Cat Form"
    local module = SN.modules.macro
    module.frame.__scripts.OnEvent(module.frame, "PLAYER_ENTERING_WORLD")
    module:Save({ spell = "Sky Vision", macroName = "Test", readyText = "READY", cooldownText = "COOLDOWN" })
"""


def macro_game():
    lua = boot()
    lua.execute(MACRO_SETUP)
    return lua


def macro_event(lua, event="SPELL_UPDATE_COOLDOWN"):
    lua.execute(f'SN.modules.macro.frame.__scripts.OnEvent(SN.modules.macro.frame, "{event}")')


def macro_body(lua):
    return lua.eval('STUB.macros[1] and STUB.macros[1].body')


@test
def macro_by_cooldown_starts_off_until_a_spell_is_set():
    lua = boot()
    assert has_module(lua, "macro")
    assert lua.eval('SN:IsModuleActive("macro")') is False, "nothing to do yet, so it starts off"
    assert lua.eval('SN:IsModuleEnabled("macro")') is False
    assert lua.eval("#STUB.macros") == 0, "no macro may be created before the player chooses a spell"
    lua.execute('SN:SetModuleEnabled("macro", true)')
    assert lua.eval('SN:IsModuleActive("macro")') is True
    assert lua.eval('(SN:GetModuleStatus("macro"))') == "warning"


@test
def macro_follows_the_spell_cooldown_and_back():
    lua = macro_game()
    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }')
    macro_event(lua)
    assert macro_body(lua) == "READY"
    assert lua.eval("#STUB.macros") == 1 and lua.eval("STUB.macros[1].perCharacter") is True

    lua.execute('STUB.cooldowns["Sky Vision"] = { 100, 120 }')
    macro_event(lua)
    assert macro_body(lua) == "COOLDOWN"

    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }')
    macro_event(lua)
    assert macro_body(lua) == "READY", "the macro must come back by itself when the spell is ready again"
    assert lua.eval("#STUB.macros") == 1, "the macro is edited in place, never duplicated"


@test
def macro_ignores_the_global_cooldown():
    lua = macro_game()
    lua.execute('STUB.cooldowns["Sky Vision"] = { 100, 1.5 }')
    macro_event(lua)
    assert macro_body(lua) == "READY"


@test
def macro_waits_for_the_end_of_combat():
    lua = macro_game()
    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }')
    macro_event(lua)
    lua.execute('STUB.inCombat = true; STUB.cooldowns["Sky Vision"] = { 100, 120 }')
    macro_event(lua)
    assert macro_body(lua) == "READY", "macros cannot be edited in combat"
    assert lua.eval("SN.modules.macro.blocked") is True
    lua.execute("STUB.inCombat = false")
    macro_event(lua, "PLAYER_REGEN_ENABLED")
    assert macro_body(lua) == "COOLDOWN"
    assert lua.eval("SN.modules.macro.blocked") is False


@test
def macro_edits_an_existing_macro_of_the_same_name():
    lua = boot()
    lua.execute('table.insert(STUB.macros, { name = "Test", body = "old" })')
    lua.execute(MACRO_SETUP)
    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }')
    macro_event(lua)
    assert lua.eval("#STUB.macros") == 1
    assert macro_body(lua) == "READY"


@test
def macro_leaves_things_alone_when_the_spell_is_unknown_or_the_module_is_off():
    lua = macro_game()
    macro_event(lua)  # no cooldown entry: the spell is not learned
    assert lua.eval("#STUB.macros") == 0
    assert lua.eval("SN.modules.macro.problem") == "unknown"

    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }')
    assert lua.eval('SN:SetModuleEnabled("macro", false)') is True, "turning it off needs no reload"
    macro_event(lua)
    assert lua.eval("#STUB.macros") == 0, "a disabled module must not touch macros"
    assert lua.eval('SN:SetModuleEnabled("macro", true)') is True
    assert macro_body(lua) == "READY"


@test
def macro_stops_when_the_character_has_no_room():
    lua = boot()
    lua.execute('for i = 1, 18 do table.insert(STUB.macros, { name = "m" .. i, body = "" }) end')
    lua.execute(MACRO_SETUP)
    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }')
    macro_event(lua)
    assert lua.eval("#STUB.macros") == 18
    assert lua.eval("SN.modules.macro.problem") == "limit"


@test
def macro_page_example_and_save_buttons_work():
    lua = boot()
    lua.execute('STUB.spellNames[1259686] = "Sky Vision"; STUB.spellNames[1850] = "Dash"; STUB.spellNames[768] = "Cat Form"')
    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }')
    lua.execute('SN:OpenPanel("macro")')
    assert lua.eval('SN:IsModuleEnabled("macro")') is False
    lua.execute('STUB.fire(STUB.findButton("Fill with the druid example"), "OnClick")')
    lua.execute('STUB.fire(STUB.findButton("Save and apply"), "OnClick")')
    assert lua.eval('SN:IsModuleEnabled("macro")') is True, "setting it up turns on a module that only started off for lack of work"
    assert lua.eval('SN:GetModuleSettings("macro").chosen') is None, "that is not the player's switch yet"
    lua.execute('local m = SN.modules.macro; m.frame.__scripts.OnEvent(m.frame, "PLAYER_ENTERING_WORLD")')
    assert lua.eval("STUB.macros[1].name") == "SNUI Cooldown"
    assert macro_body(lua) == "#showtooltip\n/cast Sky Vision"
    lua.execute('STUB.cooldowns["Sky Vision"] = { 100, 120 }')
    macro_event(lua)
    assert macro_body(lua) == "#showtooltip\n/cast [form:3] Dash\n/cast [noform:3] Cat Form"


@test
def macro_example_needs_the_spells_to_exist():
    lua = boot()
    assert lua.eval("SN.modules.macro:GetExample()") is None


@test
def macro_tries_a_numeric_icon_when_the_name_is_refused():
    lua = boot()
    lua.execute("STUB.numericIconOnly = true")
    lua.execute(MACRO_SETUP)
    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }')
    macro_event(lua)
    assert macro_body(lua) == "READY"
    assert lua.eval("type(STUB.macros[1].icon)") == "number"


@test
def macro_forgets_an_old_problem_when_it_works_and_shows_the_real_error():
    lua = boot()
    lua.execute('for i = 1, 18 do table.insert(STUB.macros, { name = "m" .. i, body = "" }) end')
    lua.execute(MACRO_SETUP)
    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }')
    macro_event(lua)
    assert lua.eval("SN.modules.macro.problem") == "limit"

    lua.execute('table.remove(STUB.macros, 1); STUB.failCreate = "boom"')
    macro_event(lua, "PLAYER_REGEN_ENABLED")
    assert lua.eval("SN.modules.macro.problem") == "failed", "an old reason must not stay on screen"
    assert "boom" in lua.eval("SN.modules.macro.errorText")

    lua.execute("STUB.failCreate = nil")
    macro_event(lua, "PLAYER_REGEN_ENABLED")
    assert lua.eval("SN.modules.macro.problem") is None
    assert lua.eval("SN.modules.macro.errorText") is None
    assert lua.eval("#STUB.macros") == 18


@test
def macro_has_no_made_up_limit():
    lua = boot()
    lua.execute("MAX_CHARACTER_MACROS = nil; STUB.macroLimit = 30")
    lua.execute('for i = 1, 27 do table.insert(STUB.macros, { name = "m" .. i, body = "" }) end')
    lua.execute(MACRO_SETUP)
    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }')
    macro_event(lua)
    assert lua.eval("#STUB.macros") == 28, "27 character macros still leave room: the game decides, not a number of ours"
    assert lua.eval("STUB.macros[28].body") == "READY"
    assert lua.eval("SN.modules.macro.problem") is None


@test
def macro_comes_back_when_the_cooldown_ends_without_any_event():
    lua = macro_game()
    # the game reports a cooldown that started at 1000 and lasts 120 s (whatever talents made it)
    lua.execute('STUB.cooldowns["Sky Vision"] = { 1000, 120 }')
    macro_event(lua)
    assert macro_body(lua) == "COOLDOWN"
    assert lua.eval("SN.modules.macro.frame.__scripts.OnUpdate") is None, "nothing may look at the spell on every frame"
    assert lua.eval("#STUB.timers") == 1, "one look is scheduled, for the moment the cooldown ends"

    lua.execute('STUB.advance(60)')
    assert macro_body(lua) == "COOLDOWN"
    # the cooldown runs out: the game says nothing, the module looks at the moment it remembered
    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }; STUB.advance(61)')
    assert macro_body(lua) == "READY"
    assert lua.eval("#STUB.timers") == 0


@test
def macro_follows_a_cooldown_that_the_game_changes():
    lua = macro_game()
    lua.execute('STUB.cooldowns["Sky Vision"] = { 1000, 120 }')
    macro_event(lua)

    # a talent or a reset shortens it: the game reports it again and the look moves up
    lua.execute('STUB.advance(10); STUB.cooldowns["Sky Vision"] = { 1000, 60 }')
    macro_event(lua)
    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }; STUB.advance(51)')
    assert macro_body(lua) == "READY", "the shorter cooldown ended at 1060"
    lua.execute("STUB.advance(200)")  # the look scheduled for the old end must do nothing
    assert macro_body(lua) == "READY"

    # a cooldown that grows without a report is caught by the look itself, which reschedules
    lua.execute('STUB.cooldowns["Sky Vision"] = { 1300, 100 }')
    macro_event(lua)
    lua.execute('STUB.advance(100); STUB.cooldowns["Sky Vision"] = { 1300, 200 }; STUB.advance(10)')
    assert macro_body(lua) == "COOLDOWN"
    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }; STUB.advance(100)')
    assert macro_body(lua) == "READY"


@test
def macro_does_not_schedule_anything_while_the_spell_is_ready_or_the_module_is_off():
    lua = macro_game()
    lua.execute('STUB.cooldowns["Sky Vision"] = { 0, 0 }')
    macro_event(lua)
    assert lua.eval("#STUB.timers") == 0
    lua.execute('STUB.cooldowns["Sky Vision"] = { 1000, 120 }')
    macro_event(lua)
    macro_event(lua)
    assert lua.eval("#STUB.timers") == 1, "the same end is not scheduled twice"
    lua.execute('SN:SetModuleEnabled("macro", false); STUB.cooldowns["Sky Vision"] = { 0, 0 }; STUB.advance(300)')
    assert macro_body(lua) == "COOLDOWN", "a disabled module must not touch the macro when an old look comes due"


@test
def macro_applies_a_cooldown_that_ended_during_combat_when_the_fight_ends():
    lua = macro_game()
    lua.execute('STUB.cooldowns["Sky Vision"] = { 1000, 30 }')
    macro_event(lua)
    lua.execute('STUB.inCombat = true; STUB.cooldowns["Sky Vision"] = { 0, 0 }; STUB.advance(31)')
    assert macro_body(lua) == "COOLDOWN"
    assert lua.eval("SN.modules.macro.blocked") is True
    lua.execute("STUB.inCombat = false")
    macro_event(lua, "PLAYER_REGEN_ENABLED")
    assert macro_body(lua) == "READY"


@test
def macro_page_explains_the_combat_alternative_with_the_two_macros():
    lua = boot()
    lua.execute('STUB.spellNames[1259686] = "Sky Vision"; STUB.spellNames[1850] = "Dash"; STUB.spellNames[768] = "Cat Form"')
    lua.execute('SN:OpenPanel("macro")')
    texts = list(lua.eval("(function() local t = {} for _, f in ipairs(STUB.frames) do t[#t + 1] = f.__text end return t end)()").values())
    assert any("[noform:3] Cat Form" in text for text in texts), "the fallback example is on the page"
    assert any(text == "#showtooltip\n/cast Sky Vision" for text in texts), "the spell example is on the page"
    assert any("Using it in combat" in text for text in texts)
    lua = boot(locale="ptBR")
    lua.execute('SN:OpenPanel("macro")')
    texts = list(lua.eval("(function() local t = {} for _, f in ipairs(STUB.frames) do t[#t + 1] = f.__text end return t end)()").values())
    assert any("Usando em combate" in text for text in texts)


@test
def every_icon_exists_where_it_is_pointed_to():
    import re as regex

    def check(icon, where):
        match = regex.match(r"Interface\\AddOns\\([^\\]+)\\(.+)$", icon)
        assert match, f"{where}: not an addon path: {icon}"
        folder, rest = match.groups()
        root = ADDON_DIR.parent / folder
        assert root.exists(), f"{where}: no folder {folder} next to the addon"
        assert (root / (rest.replace("\\", "/") + ".tga")).exists(), f"{where}: missing {rest}.tga"

    config = (ADDON_DIR / "Core" / "Config.lua").read_text(encoding="utf-8")
    check(regex.search(r'icon = "([^"]+)"', config).group(1).replace("\\\\", "\\"), "Config.lua icon")

    tocs = sorted(ADDON_DIR.glob("*.toc"))
    for companion in ADDON_DIR.parent.glob("!*"):
        tocs += sorted(companion.glob("*.toc"))
    assert len(tocs) >= 2
    for toc in tocs:
        found = regex.search(r"^## IconTexture:\s*(\S+)", toc.read_text(encoding="utf-8"), regex.MULTILINE)
        assert found, f"{toc.name} has no IconTexture"
        check(found.group(1), toc.name)


@test
def welcome_question_opens_above_the_panel_and_its_button_fits_its_text():
    lua = boot(installed=["PremadeGroupsFilter", "Rematch"])
    lua.execute('SN:OpenPanel("general")')
    assert lua.eval("SN.panel:GetFrameStrata()") == "DIALOG"
    button = lua.eval('STUB.findButton(SN:T("ask_again"))')
    assert button is not None and lua.eval('STUB.findButton(SN:T("ask_again")):GetWidth()') >= 320, "the long label needs a wide button"
    lua.execute('STUB.fire(STUB.findButton(SN:T("ask_again")), "OnClick")')
    if lua.eval("SN.welcome == nil"):
        return  # nothing recommended to ask about (the WoW Forever addon)
    order = {"BACKGROUND": 1, "LOW": 2, "MEDIUM": 3, "HIGH": 4, "DIALOG": 5, "FULLSCREEN": 6, "FULLSCREEN_DIALOG": 7, "TOOLTIP": 8}
    welcome = order[lua.eval("SN.welcome:GetFrameStrata()")]
    panel = order[lua.eval("SN.panel:GetFrameStrata()")]
    assert welcome > panel, "the question must not open behind the panel"


def open_every_page(lua):
    lua.execute("""
        SN:OpenPanel("general")
        for _, name in ipairs(SN.moduleOrder) do SN:SelectModule(name) end
        SN:AskFirstRunAgain()
    """)


@test
def every_text_uses_the_window_fonts_not_the_games():
    lua = boot()
    lua.execute('STUB.spellNames[1259686] = "Sky Vision"')
    open_every_page(lua)
    bad = lua.eval("""(function()
        local bad = {}
        for _, frame in ipairs(STUB.frames) do
            if frame.__kind == "FontString" and type(frame.__font) ~= "table" then bad[#bad + 1] = tostring(frame.__text) end
        end
        return table.concat(bad, "|")
    end)()""")
    assert bad == "", f"texts drawn with a game font object instead of the window's own: {bad}"
    names = lua.eval('(function() local t = {} for key, font in pairs(SN.Widgets.fonts) do t[#t + 1] = font.__name end return table.concat(t, ",") end)()')
    assert names.count("Font") == 4


@test
def window_font_is_blizzards_for_latin_clients_and_the_clients_own_otherwise():
    def files(lua):
        return set(lua.eval("(function() local t = {} for _, font in pairs(SN.Widgets.fonts) do t[#t + 1] = font.__file end return t end)()").values())

    for locale in ("enUS", "ptBR"):
        assert files(boot(locale=locale)) == {"Fonts\\FRIZQT__.TTF"}, locale
    korean = boot(locale="koKR", saved="STANDARD_TEXT_FONT = [[Fonts\\2002.TTF]]")
    assert files(korean) == {"Fonts\\2002.TTF"}, "an alphabet Friz Quadrata cannot draw keeps the client's own font"
    sizes = sorted(boot().eval("(function() local t = {} for _, font in pairs(SN.Widgets.fonts) do t[#t + 1] = font.__size end return t end)()").values())
    assert sizes == [10, 12, 16, 22]


@test
def buttons_are_wide_enough_for_their_text():
    lua = boot()
    lua.execute('STUB.spellNames[1259686] = "Sky Vision"; STUB.spellNames[1850] = "Dash"; STUB.spellNames[768] = "Cat Form"')
    for language in ("enUS", "ptBR"):
        lua.execute(f'SN.db.language = "{language}"; SN:UpdateLocale("{language}"); SN:RebuildPanel()')
        open_every_page(lua)
        narrow = lua.eval("""(function()
            local bad = {}
            for _, frame in ipairs(STUB.frames) do
                if frame.label and frame.__kind == "Button" and frame.label.__text ~= "" then
                    local needed = frame.label:GetStringWidth() + 14
                    local rowOfTheTree = frame.dot ~= nil
                    if not rowOfTheTree and frame:GetWidth() < needed then bad[#bad + 1] = frame.label.__text end
                end
            end
            return table.concat(bad, "|")
        end)()""")
        assert narrow == "", f"{language}: buttons narrower than their text: {narrow}"


@test
def rows_of_buttons_do_not_overlap():
    lua = boot()
    open_every_page(lua)
    overlap = lua.eval("""(function()
        local bad = {}
        for _, frame in ipairs(STUB.frames) do
            if frame.__kind == "Frame" and frame.__points[1] then
                local last
                for _, child in ipairs(STUB.frames) do
                    if child.__kind == "Button" and child.__points[1] and child.__points[1][2] == frame and child.__points[1][1] == "LEFT" then
                        if last and last.x + last.width > child.__points[1][4] + 0.5 then bad[#bad + 1] = child.label and child.label.__text or "?" end
                        last = { x = child.__points[1][4], width = child:GetWidth() }
                    end
                end
            end
        end
        return table.concat(bad, "|")
    end)()""")
    assert overlap == "", f"buttons that start before the previous one ends: {overlap}"


def star_positions(lua):
    lua.execute('SN:OpenPanel("general")')
    found = lua.eval("""(function()
        local stars = {}
        for _, frame in ipairs(STUB.frames) do
            if frame.__kind == "Texture" and frame.__width <= 2 and frame.__height <= 2 and frame.__points[1]
               and frame.__points[1][1] == "TOPLEFT" and frame.__points[1][2] == SN.panel then
                stars[#stars + 1] = { frame.__points[1][4], -frame.__points[1][5] }
            end
        end
        return stars
    end)()""")
    return [(point[1], point[2]) for point in found.values()]


@test
def the_window_has_a_sky_but_none_behind_the_page():
    stars = star_positions(boot())
    assert len(stars) >= 60, f"only {len(stars)} stars"
    for x, y in stars:
        behind_the_page = 260 < x < 784 and 46 < y < 520
        assert not behind_the_page, f"a star sits behind the page at {x:.0f},{y:.0f}"
    assert stars == star_positions(boot()), "the same seed must always draw the same sky"


@test
def a_button_grows_with_its_text_and_the_row_follows():
    lua = boot()
    first_width, second_x, second_width = lua.eval("""(function()
        local flow = SN.Widgets.NewFlow(CreateFrame("Frame"), 500)
        local row = flow:Buttons({ { text = "A very long button label here", width = 60 }, { text = "Next", width = 60 } })
        local first, second = row["A very long button label here"], row["Next"]
        return first:GetWidth(), second.__points[1][4], second:GetWidth()
    end)()""")
    assert first_width >= 29 * 7 + 14, "a button never clips its text"
    assert second_x == first_width + 8, "the next button starts where the grown one ends"
    assert second_width == 60, "a button that already fits keeps its width"


def main():
    failures = 0
    for function in TESTS:
        try:
            function()
            print(f"  ok  {function.__name__}")
        except Exception:
            failures += 1
            print(f"FAIL  {function.__name__}")
            traceback.print_exc()
    print(f"{len(TESTS) - failures}/{len(TESTS)} passed")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
