# SuperNovaUI

**Keeps your addons working after game patches.** SuperNovaUI restores Blizzard functions that were removed while addons still call them, fixes known bugs in a few popular addons while the game runs, and shows you which of your addons still have problems.

Retail only. Tested on the 12.1.5 client (interface 120100 / 120105).

---

## Which addons does it help?

**None of these addons is required.** SuperNovaUI works the same if you have only some of them, or none: each fix only has something to do when its addon is installed, and nothing breaks when it is missing.

| Addon | What SuperNovaUI does | How |
|---|---|---|
| **Rematch** (5.3.1) | Fixes the blank window, broken menus, drag and drop, and the error that stopped the pet journal from opening | Restored function + runtime fix |
| **Premade Groups Filter** | Party Fit also hides groups that already have your class and specialization | Runtime tweak |
| **ClassCodex** | Fixes the `attempt to call a nil value` errors on item functions | Restored functions |
| **CraftInfoAnywhere** | Same item-function errors (tooltips of equipped items) | Restored functions |
| **tdBattlePetScript** | Removes the pet battle constants error. Other problems of this version remain (see below) | Restored constants |
| Any other addon that still calls `MouseIsOver`, `LE_BATTLE_PET_*` or the old item functions | Same effect | Restored functions |

The compatibility menu also lists, as **Needs fix**, addons that have problems SuperNovaUI cannot repair from outside because their own code must change: **tdBattlePetScript**, **tdBattlePetScript_Rematch**, **Rematch ElvUI Skin**, **RematchCelestialTournament** and **RematchNextTarget**. Those need an update from their authors.

## What it does

### 1. Restores removed Blizzard functions (`!SuperNovaUI_Compat`)

When Blizzard removes a function, every addon that still calls it starts throwing `attempt to call a nil value`. The companion addon `!SuperNovaUI_Compat` puts the missing functions back. The leading `!` makes the game load it before all other addons, which matters for addons that call these functions while they are loading.

| Restored | Why it was removed | Fixes errors in |
|---|---|---|
| `MouseIsOver` | Removed in patch 12.1 | Rematch 5.3.1: blank window, broken menus, drag and drop, queue and notes card |
| `LE_BATTLE_PET_WEATHER / ALLY / ENEMY` | Replaced by `Enum.BattlePetOwner` | tdBattlePetScript (`attempt to ... table index is nil` during pet battles) |
| `GetItemInfo`, `GetItemInfoInstant`, `GetItemCount`, `GetDetailedItemLevelInfo`, `GetItemSpell`, `IsUsableItem`, ... | Moved to `C_Item` | ClassCodex, CraftInfoAnywhere and other addons still calling the old names |

A function is only restored when it is **missing**. SuperNovaUI never replaces Blizzard's own version or another addon's version, so it coexists with FixRematch / !RematchCompat.

### 2. Fixes bugs of other addons while the game runs

These work by wrapping one function of the other addon when you log in. **No file of the other addon is edited**, so updating that addon does not undo them.

- **Rematch (5.3.1) – NPC names.** Patch 12.1 turned the tooltip text Rematch reads NPC names from into a "secret value", which raised an error and stopped the pet journal from opening. SuperNovaUI catches that and shows `Unknown (npc id N)`, the label Rematch already uses for names it cannot find. The real names come back when Rematch ships its own fix.
- **Premade Groups Filter – Party Fit.** Party Fit used to check only free tank / healer / damage slots. It now also hides groups that already have someone with **your class and specialization**.

### 3. Compatibility menu: `/snui compat`

A window that shows, at a glance:

- **Addons that need a fix** – known addons you have installed that have problems on the current client, and whether each one is already fixed.
- **Built-in fixes** – the restored functions above and whether each one is active.
- **Tweaks** – the Premade Groups Filter tweak: *active*, *disabled*, *not hooked* or *not installed*.

`/snui compat status` prints the same in the chat.

---

## Commands

| Command | What it does |
|---|---|
| `/snui` or `/supernova` | Help |
| `/snui status` | State of every SuperNovaUI module |
| `/snui compat` | Open the compatibility menu |
| `/snui compat status` | Print the compatibility state in the chat |
| `/snui pgf` | State of the Premade Groups Filter tweak |
| `/snui rematch` | State of the Rematch fix |
| `/snui reload` | Reload the UI |

## Installation

Copy **both** folders from the zip into `World of Warcraft/_retail_/Interface/AddOns/`:

- `SuperNovaUI` – the addon and the menu
- `!SuperNovaUI_Compat` – restores the removed functions (without it that part is inactive and the menu says so)

No dependencies. Settings are kept in `SuperNovaUIDB`.

## What it never does

- It never edits, replaces or deletes files of other addons.
- The restored functions are only defined when they are missing. The two tweaks (Rematch, Premade Groups Filter) wrap one function of those addons while the game runs, and nothing is written to disk.
- It does not collect or send any data.
- It does not automate gameplay.

## Limits

- Only what can be fixed from outside an addon is fixed. Addons that need their own code changed (for example older Rematch plugins written for Rematch 4) still need an update from their author. The menu lists a few of them as **Needs fix** so you know why they misbehave.
- The Rematch fix hides the real NPC name instead of recovering it (Blizzard does not allow reading it).
- The Party Fit tweak only reaches Premade Groups Filter versions that expose the same internal functions; if it cannot hook, the menu says **not hooked**.

## FAQ

**Does it conflict with FixRematch or !RematchCompat?** No. It only defines `MouseIsOver` when nobody else did, so you can keep them or remove them.

**An error is still showing.** Open `/snui compat` and check the lists. If an addon is shown as *Needs fix*, the problem is in that addon. If it is a removed Blizzard function that is not covered yet, tell me the error text in the comments and I will add it.

**Is it safe after the next patch?** The shims only act on functions that are missing, so if Blizzard brings one back, SuperNovaUI simply stops providing it.

---

## Credits

- The `MouseIsOver` idea comes from **FixRematch / !RematchCompat** (MIT).
- Rematch is by Gello; Premade Groups Filter is by its own authors. SuperNovaUI is not affiliated with them, contains none of their code, and only wraps their public behaviour at runtime.

## License

MIT. See `LICENSE` inside each addon folder.

---
---

# SuperNovaUI (Português do Brasil)

**Mantém seus addons funcionando depois dos patches do jogo.** O SuperNovaUI devolve funções da Blizzard que foram removidas enquanto addons ainda as chamam, corrige bugs conhecidos de alguns addons populares enquanto o jogo roda e mostra quais dos seus addons ainda têm problemas.

Somente Retail. Testado no cliente 12.1.5 (interface 120100 / 120105).

---

## Quais addons ele ajuda?

**Nenhum desses addons é obrigatório.** O SuperNovaUI funciona igual se você tiver só alguns deles, ou nenhum: cada correção só tem o que fazer quando o addon dela está instalado, e nada quebra quando ele está ausente.

| Addon | O que o SuperNovaUI faz | Como |
|---|---|---|
| **Rematch** (5.3.1) | Corrige a janela em branco, os menus quebrados, o arrastar e soltar e o erro que impedia o diário de mascotes de abrir | Função devolvida + correção em tempo de execução |
| **Premade Groups Filter** | O Party Fit também esconde grupos que já têm a sua classe e especialização | Ajuste em tempo de execução |
| **ClassCodex** | Corrige os erros `attempt to call a nil value` nas funções de item | Funções devolvidas |
| **CraftInfoAnywhere** | Os mesmos erros das funções de item (tooltip dos itens equipados) | Funções devolvidas |
| **tdBattlePetScript** | Remove o erro das constantes de batalha de mascotes. Outros problemas desta versão continuam (veja abaixo) | Constantes devolvidas |
| Qualquer outro addon que ainda chame `MouseIsOver`, `LE_BATTLE_PET_*` ou as funções antigas de item | O mesmo efeito | Funções devolvidas |

O menu de compatibilidade também lista, como **Needs fix**, addons com problemas que o SuperNovaUI não consegue consertar de fora, porque o código deles precisa mudar: **tdBattlePetScript**, **tdBattlePetScript_Rematch**, **Rematch ElvUI Skin**, **RematchCelestialTournament** e **RematchNextTarget**. Esses dependem de uma atualização dos autores.

## O que ele faz

### 1. Devolve funções removidas da Blizzard (`!SuperNovaUI_Compat`)

Quando a Blizzard remove uma função, todo addon que ainda a chama passa a dar o erro `attempt to call a nil value`. O addon companheiro `!SuperNovaUI_Compat` recoloca as funções que estão faltando. O `!` no começo do nome faz o jogo carregá-lo antes de todos os outros, o que importa para addons que chamam essas funções durante o próprio carregamento.

| Devolvida | Por que sumiu | Corrige erros em |
|---|---|---|
| `MouseIsOver` | Removida no patch 12.1 | Rematch 5.3.1: janela em branco, menus quebrados, arrastar e soltar, fila e cartão de notas |
| `LE_BATTLE_PET_WEATHER / ALLY / ENEMY` | Substituídas por `Enum.BattlePetOwner` | tdBattlePetScript (erro de índice nulo durante batalhas de mascotes) |
| `GetItemInfo`, `GetItemInfoInstant`, `GetItemCount`, `GetDetailedItemLevelInfo`, `GetItemSpell`, `IsUsableItem`, ... | Foram para `C_Item` | ClassCodex, CraftInfoAnywhere e outros addons que ainda usam os nomes antigos |

Uma função só é devolvida quando está **faltando**. O SuperNovaUI nunca substitui a versão da Blizzard nem a de outro addon, então convive com o FixRematch / !RematchCompat.

### 2. Corrige bugs de outros addons enquanto o jogo roda

Funciona embrulhando uma função do outro addon quando você entra no jogo. **Nenhum arquivo do outro addon é editado**, então atualizar esse addon não desfaz a correção.

- **Rematch (5.3.1) – nomes de NPCs.** O patch 12.1 transformou o texto do tooltip, de onde o Rematch lê o nome dos NPCs, em um "valor secreto", o que gerava um erro e impedia o diário de mascotes de abrir. O SuperNovaUI captura isso e mostra `Unknown (npc id N)`, o texto que o Rematch já usa para nomes que não encontra. Os nomes reais voltam quando o Rematch lançar a própria correção.
- **Premade Groups Filter – Party Fit.** O Party Fit só verificava vagas livres de tanque, curandeiro e dano. Agora ele também esconde grupos que já têm alguém com a **sua classe e especialização**.

### 3. Menu de compatibilidade: `/snui compat`

Uma janela que mostra, de relance:

- **Addons that need a fix** – addons conhecidos que você tem instalados e que têm problemas no cliente atual, e se cada um já está corrigido.
- **Built-in fixes** – as funções devolvidas acima e se cada uma está ativa.
- **Tweaks** – o ajuste do Premade Groups Filter: *active*, *disabled*, *not hooked* ou *not installed*.

O `/snui compat status` imprime o mesmo no chat.

---

## Comandos

| Comando | O que faz |
|---|---|
| `/snui` ou `/supernova` | Ajuda |
| `/snui status` | Estado de cada módulo do SuperNovaUI |
| `/snui compat` | Abre o menu de compatibilidade |
| `/snui compat status` | Imprime o estado da compatibilidade no chat |
| `/snui pgf` | Estado do ajuste do Premade Groups Filter |
| `/snui rematch` | Estado da correção do Rematch |
| `/snui reload` | Recarrega a interface |

## Instalação

Copie **as duas** pastas do zip para `World of Warcraft/_retail_/Interface/AddOns/`:

- `SuperNovaUI` – o addon e o menu
- `!SuperNovaUI_Compat` – devolve as funções removidas (sem ela essa parte fica inativa e o menu avisa)

Sem dependências. As configurações ficam em `SuperNovaUIDB`.

## O que ele nunca faz

- Nunca edita, substitui nem apaga arquivos de outros addons.
- As funções devolvidas só são definidas quando estão faltando. Os dois ajustes (Rematch, Premade Groups Filter) embrulham uma função desses addons enquanto o jogo roda, e nada é gravado em disco.
- Não coleta nem envia nenhum dado.
- Não automatiza o jogo.

## Limites

- Só é corrigido o que dá para corrigir de fora de um addon. Addons que precisam de mudança no próprio código (por exemplo plugins antigos do Rematch, escritos para o Rematch 4) ainda precisam de atualização do autor. O menu lista alguns deles como **Needs fix** para você saber por que se comportam mal.
- A correção do Rematch esconde o nome real do NPC em vez de recuperá-lo (a Blizzard não permite lê-lo).
- O ajuste do Party Fit só alcança versões do Premade Groups Filter que expõem as mesmas funções internas; se não conseguir se encaixar, o menu mostra **not hooked**.

## Perguntas frequentes

**Conflita com o FixRematch ou o !RematchCompat?** Não. Ele só define o `MouseIsOver` quando ninguém mais definiu, então você pode manter ou remover esses addons.

**Um erro continua aparecendo.** Abra `/snui compat` e veja as listas. Se um addon aparece como *Needs fix*, o problema está nele. Se for uma função removida da Blizzard ainda não coberta, mande o texto do erro nos comentários e eu a adiciono.

**É seguro depois do próximo patch?** As correções só agem sobre funções que estão faltando; se a Blizzard trouxer uma de volta, o SuperNovaUI simplesmente deixa de fornecê-la.

---

## Créditos

- A ideia do `MouseIsOver` vem do **FixRematch / !RematchCompat** (MIT).
- O Rematch é de Gello; o Premade Groups Filter é dos autores dele. O SuperNovaUI não é afiliado a eles, não contém código deles e apenas embrulha o comportamento público em tempo de execução.

## Licença

MIT. Veja o arquivo `LICENSE` dentro de cada pasta do addon.
