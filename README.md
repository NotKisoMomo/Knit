# Mitt - Roblox Input Library

[![Static Badge](https://img.shields.io/badge/build-v1.0.0-black)](https://github.com/NotKisoMomo)
![Static Badge](https://img.shields.io/badge/stability-stable-green)

Mitt is a full-stack input library for Roblox. It provides a unified action registry, context-aware filtering, combo and shortcut detection, Promise-based async flows, session-based state containers, and raw input access -- all in one client-side module.

---

## Table of Contents

* [Features](#features)
* [Installation](#installation)
* [Quick Start](#quick-start)
* [Core Concepts](#core-concepts)
  * [How Mitt Thinks About Input](#how-mitt-thinks-about-input)
  * [Actions and Handles](#actions-and-handles)
  * [Type Inference](#type-inference)
  * [Context Stack](#context-stack)
  * [Signals vs Promises](#signals-vs-promises)
  * [Sessions](#sessions)
* [API Reference](#api-reference)
  * [Mitt.define](#mittdefine)
  * [Action Handle](#action-handle)
  * [Signals](#signals)
  * [Promises](#promises)
  * [Context](#context)
  * [Sessions](#sessions-api)
  * [Raw Input](#raw-input)
  * [Helpers](#helpers)
  * [Registry](#registry)
* [Patterns](#patterns)
  * [Charge Attack](#charge-attack)
  * [Input Buffering](#input-buffering)
  * [Context Switching](#context-switching)
  * [Session-driven Combat State](#session-driven-combat-state)
  * [Settings Screen Rebinding](#settings-screen-rebinding)
  * [Tutorial Gating](#tutorial-gating)
* [Combat Example](#combat-example)
* [Exported Types](#exported-types)
* [Contact](#contact)

---

## Features

* **Unified Action Registry:** Define once with `Mitt.define`, get a handle back. Reference actions by variable -- no string lookups, no global tables.
* **Auto-inferred Action Types:** Mitt reads your `bindings` and decides `button` vs `axis` automatically. No `type` field needed unless you want to override.
* **Context Stack:** A named layer system. Push `"menu"` and gameplay actions go silent without touching a single listener. Pop it and everything resumes.
* **Combo Detection:** Sequential input sequences with a configurable timing window. Bindings are inferred from the sequence automatically.
* **Shortcut Detection:** Simultaneous held inputs that fire a single `triggered` signal.
* **Promise-based Async:** One-shot operations return cancellable Promises. Race two inputs, sequence them in order, await them inside tasks.
* **Hold Detection:** `holdFor(n)` returns a Promise that resolves after an action has been continuously held for `n` seconds.
* **Repeat Mode:** Held buttons re-fire `pressed` on a fixed interval. Good for rapid-fire weapons or held-scroll.
* **Deadzone Filtering:** Axis actions below a magnitude threshold are silently dropped -- eliminates stick drift.
* **Input Buffering:** `Mitt.buffer(action, window)` opens a timed window and resolves if the action fires within it. Purpose-built for queuing inputs during hitstun.
* **Sessions:** Named state containers with reactive change signals. Replace scattered `local buffered = false` variables with a single structured session per system.
* **Raw Input Layer:** Per-key listeners that bypass the action system entirely. No context filter, always fires.
* **Runtime Rebinding:** Swap bindings on any live action with `:rebind()`. Bulk-rebind all actions at once with `Mitt.rebindAll()`.
* **Export / Import:** Serialize all current bindings to a plain table. Useful for saving keybind preferences to a datastore.
* **Visualizer:** `Mitt.visualizer()` opens a live overlay showing every registered action's current state, color-coded by phase.

---

## Installation

Place the Mitt folder into `ReplicatedStorage`, then require it on the client. Mitt is a **client-only** library. Never require it from a server Script.

```lua
local Mitt = require(game.ReplicatedStorage.Mitt)
```

---

## Quick Start

```lua
local Mitt = require(game.ReplicatedStorage.Mitt)

local Jump = Mitt.define("Jump", {
    bindings = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA },
    contexts = { "gameplay" },
})

local Look = Mitt.define("Look", {
    bindings = { Enum.UserInputType.MouseMovement },
    contexts = { "gameplay" },
    deadzone = 1.5,
})

local Dash = Mitt.define("Dash", {
    contexts = { "gameplay" },
    mode     = "combo",
    sequence = { Enum.KeyCode.W, Enum.KeyCode.W },
    window   = 0.3,
})

local State = Mitt.createSession("Movement", {
    jumping  = false,
    dashing  = false,
    airborne = false,
})

Jump.pressed:connect(function(event)
    event:consume()
    State:set("jumping", true)
    character:Jump()
end)

Jump.released:connect(function()
    State:set("jumping", false)
end)

Look.moved:connect(function(event)
    camera:ApplyDelta(event.delta)
end)

Dash.triggered:connect(function()
    State:set("dashing", true)
    character:Dash()
    task.delay(0.4, function()
        State:set("dashing", false)
    end)
end)

Mitt.context.push("gameplay")
```

---

## Core Concepts

### How Mitt Thinks About Input

Without Mitt, input handling in Roblox looks like this:

```lua
local buffered = false
local charging = false
local blocking = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Space then
        charging = true
        character:Jump()
    end
end)
```

Once you have 20 actions, different game states, combos, held detection, rebinding, and a handful of transient booleans scattered across the module -- it becomes unmaintainable.

Mitt solves both sides of this. Actions replace the `InputBegan` wall. Sessions replace the scattered state variables.

---

### Actions and Handles

`Mitt.define` registers an action and returns a handle. Hold onto it -- it is the only way to interact with that action. There is no retrieval-by-string by design. Define at the top of your module, use the handle everywhere.

```lua
local Jump = Mitt.define("Jump", {
    bindings = { Enum.KeyCode.Space },
    contexts = { "gameplay" },
})

Jump.pressed:connect(function(event)
    character:Jump()
end)

return { Jump = Jump }
```

---

### Type Inference

Mitt reads your `bindings` and classifies the action as `button` or `axis`:

| Binding | Inferred type |
|---------|--------------|
| Any `KeyCode` except thumbsticks | `button` |
| `MouseButton1`, `MouseButton2`, `MouseButton3` | `button` |
| `MouseMovement`, `MouseWheel` | `axis` |
| `Thumbstick1`, `Thumbstick2` | `axis` |
| `Gyro`, `Accelerometer` | `axis` |

For `button` actions the useful signals are `pressed`, `released`, and `held`. For `axis` actions the useful signal is `moved`, which carries `event.delta` and `event.position`. Override with an explicit `mode` field if needed.

---

### Context Stack

The context stack is a LIFO list of named strings. An action only fires if its declared `contexts` contains something present anywhere in the stack. Actions with no `contexts` always fire.

```lua
Mitt.context.push("gameplay")
-- Jump (contexts={"gameplay"}) fires
-- MenuConfirm (contexts={"menu"}) silent

Mitt.context.push("menu")
-- Jump still fires -- gameplay is still in the stack
-- MenuConfirm now fires too

Mitt.context.pop()
-- back to gameplay only, no listeners touched
```

---

### Signals vs Promises

**Signals** (`:connect`) -- persistent, fires every time the action fires.

```lua
Jump.pressed:connect(function(event)
    character:Jump()
end)
```

**Promises** (`:once()`, `:next()`) -- one-shot, fires once then cleans itself up.

```lua
Jump.pressed:once():andThen(function(event)
    print("first jump ever")
end)
```

Rule of thumb: persistent response -- Signal. One specific moment -- Promise.

---

### Sessions

Sessions are named state containers managed by Mitt. They replace scattered module-level variables like `local buffered = false` or `local combo = 0` with a single structured object per system. Every key change fires a signal -- you can react to state instead of polling it.

```lua
-- instead of this
local charging  = false
local blocking  = false
local comboStep = 0

-- do this
local CombatState = Mitt.createSession("Combat", {
    charging  = false,
    blocking  = false,
    comboStep = 0,
})
```

Sessions are globally accessible by name via `Mitt.getSession`, so other modules can read or react to state without needing direct references passed around.

---

## API Reference

### Mitt.define

```lua
Mitt.define(name: string, config: ActionConfig) -> ActionHandle
```

Registers an action and returns its handle. Errors if `name` is already registered.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `bindings` | `{ KeyCode \| UserInputType }` | required | Input sources. Omit for combos -- inferred from `sequence`. |
| `contexts` | `{ string }?` | nil | Contexts in which this action fires. Omit to fire everywhere. |
| `mode` | `ActionMode?` | inferred | Override: `"button"`, `"axis"`, `"combo"`, `"shortcut"`. |
| `sequence` | `{ KeyCode \| UserInputType }?` | nil | Ordered input sequence for `combo` mode. |
| `window` | `number?` | `0.4` | Max seconds between each step in a combo. |
| `deadzone` | `number?` | `0.0` | Axis deltas below this magnitude are dropped. |
| `repeatInterval` | `number?` | nil | Held button re-fires `pressed` every `n` seconds. |

---

### Action Handle

The object returned by `Mitt.define`.

---

### Signals

| Signal | Fires when | Relevant for |
|--------|-----------|-------------|
| `pressed` | Binding goes from up to down | `button`, `shortcut` |
| `released` | Binding goes from down to up | `button` |
| `held` | Binding is held per Heartbeat | `button` |
| `moved` | Axis input produces a delta | `axis` |
| `triggered` | Combo or shortcut completes | `combo`, `shortcut` |

```lua
local disconnect = Jump.pressed:connect(function(event)
    character:Jump()
end)

disconnect()

Jump.pressed:once():andThen(function(event)
    print("jumped")
end)
```

#### InputEvent fields

| Field | Type | Description |
|-------|------|-------------|
| `binding` | `KeyCode \| UserInputType` | The specific binding that fired. |
| `phase` | `"pressed" \| "released" \| "changed"` | Which phase this is. |
| `position` | `Vector2?` | Screen position. Nil for non-positional inputs. |
| `delta` | `Vector2?` | Movement delta. Only on axis inputs. |
| `held` | `boolean` | True only on repeat-mode ticks. |
| `consumed` | `boolean` | Whether `:consume()` has been called. Readonly. |

**`:consume()`** stops propagation -- remaining subscribers for this action won't receive the event.

---

### State Helpers

```lua
Jump:isHeld()          -- boolean
Jump:heldDuration()    -- number -- seconds held, 0 if not held

Jump:holdFor(0.5):andThen(function()
    Combat:HeavyAttack()
end)

Jump:next():andThen(function(event)
    print("jumped")
end)

Jump:log()
```

---

### Management

```lua
Jump:rebind({ Enum.KeyCode.X, Enum.KeyCode.ButtonB })
Jump:disable()
Jump:enable()
Jump:destroy()
```

---

### Promises

```lua
promise
    :andThen(function(value) end)
    :catch(function(err) end)
    :cancel()
    :await()   -- yields thread, returns (ok, value)
```

---

### Sessions API

#### Mitt.createSession

```lua
Mitt.createSession(name: string, defaults: { [string]: any }) -> SessionHandle
```

Creates a named session with default values. If the session already exists, returns the existing one.

```lua
local CombatState = Mitt.createSession("Combat", {
    charging   = false,
    blocking   = false,
    comboStep  = 0,
    lastAttack = "",
})
```

---

#### Mitt.getSession

```lua
Mitt.getSession(name: string) -> SessionHandle?
```

Retrieves an existing session by name. Returns nil if not found. Use this to access session state from a different module without passing references.

```lua
local CombatState = Mitt.getSession("Combat")
if CombatState then
    print(CombatState:get("blocking"))
end
```

---

#### Mitt.modifySession

```lua
Mitt.modifySession(name: string, data: { [string]: any })
```

Patches a session by name without needing the handle. Errors if the session doesn't exist.

```lua
Mitt.modifySession("Combat", { blocking = true, comboStep = 0 })
```

---

#### Mitt.removeSession

```lua
Mitt.removeSession(name: string)
```

Destroys a session and removes it from the registry.

---

#### SessionHandle methods

```lua
CombatState:get("charging")           -- any

CombatState:set("charging", true)

CombatState:patch({ charging = true, comboStep = 2 })

CombatState:toggle("blocking")        -- boolean

CombatState:increment("comboStep")    -- number
CombatState:increment("comboStep", 2)

CombatState:decrement("comboStep")    -- number

CombatState:reset()

local disconnect = CombatState:onChange("charging", function(new, prev)
    print("charging changed:", prev, "->", new)
end)

local disconnect = CombatState:onAnyChange(function(key, new, prev)
    print(key, "changed:", prev, "->", new)
end)

CombatState:snapshot()                -- { [string]: any }

CombatState:destroy()
```

---

### Context

```lua
Mitt.context.push("gameplay")
Mitt.context.pop()
Mitt.context.peek()              -- string?
Mitt.context.has("gameplay")    -- boolean -- anywhere in stack
Mitt.context.stack()             -- { string } -- full copy
Mitt.context.clear()

Mitt.context.changed:connect(function(stack)
    print("top:", stack[#stack])
end)
```

---

### Raw Input

Bypasses the action system. No context filter, no handle, fires on every matching input.

```lua
local disconnect = Mitt.input.on(Enum.KeyCode.BackQuote, function(event)
    DebugPanel:Toggle()
end)

Mitt.input.held(Enum.KeyCode.LeftShift)  -- boolean

disconnect()
```

---

### Helpers

#### Mitt.race
```lua
Mitt.race(signals: { Signal }) -> Promise
```
Resolves with the first signal that fires. Cancels all others immediately.

#### Mitt.sequence
```lua
Mitt.sequence(promises: { Promise }) -> Promise<{ any }>
```
Awaits each Promise left to right. Resolves with all values. Cancels all and rejects if any fails.

#### Mitt.timeout
```lua
Mitt.timeout(promise: Promise, seconds: number) -> Promise
```
Wraps any Promise with a deadline. Rejects with `"timeout"` if it doesn't resolve in time.

#### Mitt.buffer
```lua
Mitt.buffer(action: ActionHandle, window: number) -> Promise
```
Opens a timed window on `action.pressed`. Resolves if pressed within the window -- purpose-built for hitstun buffering.

#### Mitt.waitFor
```lua
Mitt.waitFor(action: ActionHandle, phase: Phase?) -> Promise
```
One-shot wait on any action signal by phase. Defaults to `"pressed"`.

#### Mitt.rebindAll
```lua
Mitt.rebindAll(map: { [string]: { InputBinding } })
```
Bulk-rebinds multiple actions from a name-keyed table.

#### Mitt.export / Mitt.import
```lua
Mitt.export() -> { [string]: { string } }
Mitt.import(map: { [string]: { InputBinding } })
```
Serialize and restore all bindings. Safe to save to a datastore.

#### Mitt.visualizer
```lua
Mitt.visualizer() -> ScreenGui
```
Live input overlay. Purple = pressed, green = triggered, yellow = axis delta, gray = idle. Remove before shipping.

---

### Registry

```lua
Mitt.get("Jump")      -- ActionHandle? -- prefer passing the handle directly
Mitt.action("Jump")   -- alias for Mitt.get
Mitt.remove("Jump")   -- destroy and unregister an action
Mitt.clear()          -- destroy all actions and listeners
```

---

## Patterns

### Charge Attack

Tap for light, hold for heavy. Session tracks the charge state cleanly.

```lua
local CombatState = Mitt.createSession("Combat", {
    charging = false,
})

local chargePromise

Attack.pressed:connect(function()
    CombatState:set("charging", true)
    chargePromise = Attack:holdFor(0.6):andThen(function()
        CombatState:set("charging", false)
        Combat:HeavyAttack()
        chargePromise = nil
    end)
end)

Attack.released:connect(function()
    if chargePromise then
        chargePromise:cancel()
        chargePromise = nil
    end
    if CombatState:get("charging") then
        CombatState:set("charging", false)
        Combat:LightAttack()
    end
end)
```

---

### Input Buffering

Session tracks the buffered state. No module-level variables needed.

```lua
local CombatState = Mitt.createSession("Combat", {
    buffered = false,
})

Combat.hitstunStarted:Connect(function()
    Mitt.buffer(Attack, 0.25):andThen(function()
        CombatState:set("buffered", true)
    end)
end)

Combat.hitstunEnded:Connect(function()
    if CombatState:toggle("buffered") == false then
        Combat:Attack()
    end
end)
```

---

### Context Switching

```lua
local function openMenu()
    Mitt.context.push("menu")
end

local function closeMenu()
    Mitt.context.pop()
end

openMenu()          -- stack: ["gameplay", "menu"]
openInventory()     -- stack: ["gameplay", "menu", "inventory"]
closeInventory()    -- stack: ["gameplay", "menu"]
closeMenu()         -- stack: ["gameplay"]
```

---

### Session-driven Combat State

All combat flags in one place. React to changes anywhere in the codebase.

```lua
local CombatState = Mitt.createSession("Combat", {
    blocking  = false,
    charging  = false,
    comboStep = 0,
    stunned   = false,
})

CombatState:onChange("blocking", function(blocking)
    character.Humanoid.WalkSpeed = blocking and 8 or 16
end)

CombatState:onAnyChange(function(key, new, prev)
    print(string.format("[CombatState] %s: %s -> %s", key, tostring(prev), tostring(new)))
end)

Block.pressed:connect(function()  CombatState:set("blocking", true)  end)
Block.released:connect(function() CombatState:set("blocking", false) end)

LightAttack.pressed:connect(function()
    CombatState:increment("comboStep")
    if CombatState:get("comboStep") >= 3 then
        CombatState:set("comboStep", 0)
        Combat:ComboFinisher()
    end
end)

Combat.stunned:Connect(function()
    CombatState:patch({ stunned = true, comboStep = 0, charging = false })
end)

local state = Mitt.getSession("Combat"):snapshot()
print(state.blocking, state.comboStep)
```

---

### Settings Screen Rebinding

```lua
local function openSettings()
    SettingsUI:Populate(Mitt.export())
end

local function applySettings(newBindings)
    Mitt.import(newBindings)
    DataStore:SetAsync(userId, newBindings)
end
```

---

### Tutorial Gating

```lua
local function runTutorial()
    UI:ShowPrompt("Press Space to jump")
    Mitt.context.push("tutorial")

    local TutJump = Mitt.define("TutJump", {
        bindings = { Enum.KeyCode.Space },
        contexts = { "tutorial" },
    })

    TutJump.pressed:once():andThen(function()
        Mitt.context.pop()
        Mitt.remove("TutJump")
        UI:HidePrompt()
    end)
end
```

---

## Combat Example

```lua
local Mitt = require(game.ReplicatedStorage.Mitt)

local LightAttack = Mitt.define("LightAttack", {
    bindings = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR1 },
    contexts = { "gameplay" },
})

local HeavyAttack = Mitt.define("HeavyAttack", {
    bindings = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonR2 },
    contexts = { "gameplay" },
})

local Block = Mitt.define("Block", {
    bindings = { Enum.KeyCode.F, Enum.KeyCode.ButtonL1 },
    contexts = { "gameplay" },
})

local Dodge = Mitt.define("Dodge", {
    contexts = { "gameplay" },
    mode     = "combo",
    sequence = { Enum.KeyCode.Q, Enum.KeyCode.Q },
    window   = 0.25,
})

local Parry = Mitt.define("Parry", {
    bindings = { Enum.KeyCode.F, Enum.KeyCode.LeftShift },
    contexts = { "gameplay" },
    mode     = "shortcut",
})

local MenuConfirm = Mitt.define("MenuConfirm", {
    bindings = { Enum.KeyCode.Return, Enum.KeyCode.ButtonA },
    contexts = { "menu" },
})

local CombatState = Mitt.createSession("Combat", {
    blocking  = false,
    charging  = false,
    comboStep = 0,
    buffered  = false,
})

CombatState:onChange("blocking", function(blocking)
    character.Humanoid.WalkSpeed = blocking and 8 or 16
end)

local attackPromise

LightAttack.pressed:connect(function(event)
    event:consume()
    CombatState:set("charging", true)
    attackPromise = LightAttack:holdFor(0.4):andThen(function()
        CombatState:set("charging", false)
        Combat:HeavyAttack()
        attackPromise = nil
    end)
end)

LightAttack.released:connect(function()
    if attackPromise then
        attackPromise:cancel()
        attackPromise = nil
    end
    if CombatState:get("charging") then
        CombatState:set("charging", false)
        CombatState:increment("comboStep")
        Combat:LightAttack()
    end
end)

Block.pressed:connect(function()  CombatState:set("blocking", true)  end)
Block.released:connect(function() CombatState:set("blocking", false) end)

Parry.triggered:connect(function(event)
    event:consume()
    Mitt.timeout(
        Mitt.race({ LightAttack.pressed, HeavyAttack.pressed }),
        0.2
    ):andThen(function()
        Combat:Parry()
    end)
end)

Dodge.triggered:connect(function()
    Combat:Dodge()
end)

Combat.hitstunStarted:Connect(function()
    Mitt.buffer(LightAttack, 0.3):andThen(function()
        CombatState:set("buffered", true)
    end)
end)

Combat.hitstunEnded:Connect(function()
    if CombatState:get("buffered") then
        CombatState:set("buffered", false)
        Combat:QueueAttack()
    end
end)

MenuConfirm.pressed:connect(function(event)
    event:consume()
    Menu:Confirm()
end)

Mitt.context.push("gameplay")
```

---

## Exported Types

```lua
export type ActionMode   = "button" | "axis" | "combo" | "shortcut"
export type InputBinding = Enum.KeyCode | Enum.UserInputType
export type Phase        = "pressed" | "released" | "changed"

export type ActionConfig = {
    bindings:       { InputBinding },
    contexts:       { string }?,
    mode:           ActionMode?,
    sequence:       { InputBinding }?,
    window:         number?,
    deadzone:       number?,
    repeatInterval: number?,
}

export type InputEvent = {
    binding:  InputBinding,
    phase:    Phase,
    position: Vector2?,
    delta:    Vector2?,
    held:     boolean,
    consumed: boolean,
    consume:  (self: InputEvent) -> (),
}

export type Signal<T> = {
    connect: (self: Signal<T>, cb: (T) -> ()) -> () -> (),
    once:    (self: Signal<T>) -> Promise<T>,
}

export type Promise<T> = {
    andThen: (self: Promise<T>, cb: (T) -> ()) -> Promise<T>,
    catch:   (self: Promise<T>, cb: (any) -> ()) -> Promise<T>,
    cancel:  (self: Promise<T>) -> (),
    await:   (self: Promise<T>) -> (boolean, T),
}

export type ActionHandle = {
    pressed:   Signal<InputEvent>,
    released:  Signal<InputEvent>,
    held:      Signal<InputEvent>,
    moved:     Signal<InputEvent>,
    triggered: Signal<InputEvent>,

    isHeld:       (self: ActionHandle) -> boolean,
    heldDuration: (self: ActionHandle) -> number,
    holdFor:      (self: ActionHandle, seconds: number) -> Promise<InputEvent>,
    next:         (self: ActionHandle) -> Promise<InputEvent>,
    log:          (self: ActionHandle) -> (),
    rebind:       (self: ActionHandle, bindings: { InputBinding }) -> (),
    enable:       (self: ActionHandle) -> (),
    disable:      (self: ActionHandle) -> (),
    destroy:      (self: ActionHandle) -> (),
}

export type SessionHandle = {
    get:         (self: SessionHandle, key: string) -> any,
    set:         (self: SessionHandle, key: string, value: any) -> (),
    patch:       (self: SessionHandle, data: { [string]: any }) -> (),
    toggle:      (self: SessionHandle, key: string) -> boolean,
    increment:   (self: SessionHandle, key: string, amount: number?) -> number,
    decrement:   (self: SessionHandle, key: string, amount: number?) -> number,
    reset:       (self: SessionHandle) -> (),
    onChange:    (self: SessionHandle, key: string, cb: (any, any) -> ()) -> () -> (),
    onAnyChange: (self: SessionHandle, cb: (string, any, any) -> ()) -> () -> (),
    snapshot:    (self: SessionHandle) -> { [string]: any },
    destroy:     (self: SessionHandle) -> (),
}
```

All types exported from `Mitt/Types.lua` and re-exported by the main module.

---

## Contact

| Platform | Handle |
|---|---|
| Roblox | [Kr3ativeKrayon](https://www.roblox.com/users/1911367519/profile) |
| YouTube | [TotallyKr3ative](https://www.youtube.com/channel/UCpNZQoKVclQ74Pk5GmzdQDA) |
| X (Twitter) | [TotallyNotKr3ative](https://x.com/TheRealKr3ative) |
| Email | [TheRealKr3ative@gmail.com](mailto:TheRealKr3ative@gmail.com) |

---

*Built by Plinko Labs*

*Last Updated: May 23, 2026*

---
