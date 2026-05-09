# Knit - Roblox Input Library

[![Static Badge](https://img.shields.io/badge/build-v1.0.0-black)](https://github.com/TheRealKr3ative)
![Static Badge](https://img.shields.io/badge/stability-stable-green)

Knit is a full-stack input library for Roblox. It provides a unified action registry, context-aware filtering, combo and shortcut detection, Promise-based async flows, and raw input access -- all in one client-side module.

---

## Table of Contents

* [Features](#features)
* [Installation](#installation)
* [Quick Start](#quick-start)
* [Core Concepts](#core-concepts)
  * [How Knit Thinks About Input](#how-knit-thinks-about-input)
  * [Actions and Handles](#actions-and-handles)
  * [Type Inference](#type-inference)
  * [Context Stack](#context-stack)
  * [Signals vs Promises](#signals-vs-promises)
* [API Reference](#api-reference)
  * [Knit.define](#knitdefine)
  * [Action Handle](#action-handle)
  * [Signals](#signals)
  * [Promises](#promises)
  * [Context](#context)
  * [Raw Input](#raw-input)
  * [Helpers](#helpers)
  * [Registry](#registry)
* [Patterns](#patterns)
  * [Charge Attack](#charge-attack)
  * [Input Buffering](#input-buffering)
  * [Context Switching](#context-switching)
  * [Settings Screen Rebinding](#settings-screen-rebinding)
  * [Tutorial Gating](#tutorial-gating)
* [Combat Example](#combat-example)
* [Exported Types](#exported-types)
* [Contact](#contact)

---

## Features

* **Unified Action Registry:** Define once with `Knit.define`, get a handle back. Reference actions by variable -- no string lookups, no global tables.
* **Auto-inferred Action Types:** Knit reads your `bindings` and decides `button` vs `axis` automatically. No `type` field needed unless you want to override.
* **Context Stack:** A named layer system. Push `"menu"` and gameplay actions go silent without touching a single listener. Pop it and everything resumes.
* **Combo Detection:** Sequential input sequences with a configurable timing window. Bindings are inferred from the sequence automatically.
* **Shortcut Detection:** Simultaneous held inputs that fire a single `triggered` signal.
* **Promise-based Async:** One-shot operations return cancellable Promises. Race two inputs, sequence them in order, await them inside tasks.
* **Hold Detection:** `holdFor(n)` returns a Promise that resolves after an action has been continuously held for `n` seconds.
* **Repeat Mode:** Held buttons re-fire `pressed` on a fixed interval. Good for rapid-fire weapons or held-scroll.
* **Deadzone Filtering:** Axis actions below a magnitude threshold are silently dropped -- eliminates stick drift.
* **Input Buffering:** `Knit.buffer(action, window)` opens a timed window and resolves if the action fires within it. Purpose-built for queuing inputs during hitstun.
* **Raw Input Layer:** Per-key listeners that bypass the action system entirely. No context filter, always fires.
* **Runtime Rebinding:** Swap bindings on any live action with `:rebind()`. Bulk-rebind all actions at once with `Knit.rebindAll()`.
* **Export / Import:** Serialize all current bindings to a plain table. Useful for saving keybind preferences to a datastore.
* **Visualizer:** `Knit.visualizer()` opens a live overlay showing every registered action's current state, color-coded by phase.

---

## Installation

Place the Knit folder into `ReplicatedStorage`, then require it on the client. Knit is a **client-only** library. Never require it from a server Script -- it calls `UserInputService` at the module level and will error.

```lua
local Knit = require(game.ReplicatedStorage.Knit)
```

---

## Quick Start

```lua
local Knit = require(game.ReplicatedStorage.Knit)

-- define actions once at the top of your module
local Jump = Knit.define("Jump", {
    bindings = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA },
    contexts = { "gameplay" },
})

local Look = Knit.define("Look", {
    bindings = { Enum.UserInputType.MouseMovement },
    contexts = { "gameplay" },
    deadzone = 1.5,
})

local Dash = Knit.define("Dash", {
    contexts = { "gameplay" },
    mode     = "combo",
    sequence = { Enum.KeyCode.W, Enum.KeyCode.W },
    window   = 0.3,
})

-- subscribe
Jump.pressed:connect(function(event)
    event:consume()
    character:Jump()
end)

Look.moved:connect(function(event)
    camera:ApplyDelta(event.delta)
end)

Dash.triggered:connect(function()
    character:Dash()
end)

-- activate the context -- actions are silent until you do this
Knit.context.push("gameplay")
```

---

## Core Concepts

### How Knit Thinks About Input

Without Knit, input handling in Roblox looks like this:

```lua
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Space then
        character:Jump()
    end
end)
```

This works for one action. Once you have 20 actions, different game states, combos, held detection, and rebinding -- it becomes a wall of conditionals that are hard to maintain and impossible to disable cleanly.

Knit centralises all of that. You define what an action *is* once, then subscribe to what it *does* in as many places as you want. The context system means you never have to manually disconnect anything when switching game states -- you just push a context.

---

### Actions and Handles

`Knit.define` is the only way to create an action. It returns a **handle** -- a live object you hold onto and use everywhere that action is needed.

```lua
-- define at module level
local Jump = Knit.define("Jump", {
    bindings = { Enum.KeyCode.Space },
    contexts = { "gameplay" },
})

-- use the handle anywhere in the same module
Jump.pressed:connect(function(event)
    character:Jump()
end)

-- or export it for other modules to subscribe to
return { Jump = Jump }
```

There is no `Knit.action("Jump")` retrieval by design -- if you need the handle somewhere else, pass it or export it. This keeps intent explicit and avoids hidden string coupling between modules. The one exception is `Knit.get(name)` for debug tooling and edge cases.

---

### Type Inference

Knit reads your `bindings` array and automatically classifies the action as `button` or `axis`:

| Binding | Inferred type |
|---------|--------------|
| Any `KeyCode` except thumbsticks | `button` |
| `MouseButton1`, `MouseButton2`, `MouseButton3` | `button` |
| `MouseMovement`, `MouseWheel` | `axis` |
| `Thumbstick1`, `Thumbstick2` | `axis` |
| `Gyro`, `Accelerometer` | `axis` |

For `button` actions the useful signals are `pressed`, `released`, and `held`. For `axis` actions the useful signal is `moved`, which carries `event.delta` and `event.position`. If Knit infers wrong, set `mode` explicitly in the config.

---

### Context Stack

The context stack is a last-in-first-out list of named strings representing the current game state. An action only fires if its declared `contexts` contains something that appears anywhere in the stack.

```lua
-- nothing active at start
Knit.context.push("gameplay")
-- stack: ["gameplay"]
-- Jump (contexts={"gameplay"}) -- fires
-- MenuConfirm (contexts={"menu"}) -- silent

Knit.context.push("menu")
-- stack: ["gameplay", "menu"]
-- Jump -- still fires (gameplay is still in the stack)
-- MenuConfirm -- now fires too

Knit.context.pop()
-- stack: ["gameplay"]
-- back to gameplay only, no listeners touched
```

Actions with **no `contexts` field** fire regardless of the stack. Use this for global hotkeys -- a debug toggle, a screenshot key, a `ToggleMenu` button.

---

### Signals vs Promises

Knit exposes two ways to listen to an action:

**Signals** (`:connect`) are for persistent subscriptions -- things that should respond every time the action fires.

```lua
Jump.pressed:connect(function(event)
    character:Jump()
end)
```

**Promises** (`:once()`, `:next()`) are for one-shot flows -- things that should happen exactly once, or that are part of a timed or ordered sequence.

```lua
-- fires once, then the subscription is gone
Jump.pressed:once():andThen(function(event)
    print("first jump ever")
end)
```

The rule of thumb: if it should respond every time -- Signal. If it should respond once and stop -- Promise.

---

## API Reference

### Knit.define

```lua
Knit.define(name: string, config: ActionConfig) -> ActionHandle
```

Registers an action and returns its handle. Errors immediately if `name` is already registered.

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

The object returned by `Knit.define`. Everything you need lives here.

---

### Signals

All signals expose `:connect(cb)` returning a disconnect function, and `:once()` returning a Promise.

| Signal | Fires when | Relevant for |
|--------|-----------|-------------|
| `pressed` | A binding goes from up to down | `button`, `shortcut` |
| `released` | A binding goes from down to up | `button` |
| `held` | A binding is held (per Heartbeat) | `button` |
| `moved` | An axis input produces a delta | `axis` |
| `triggered` | A combo or shortcut completes | `combo`, `shortcut` |

```lua
local disconnect = Jump.pressed:connect(function(event)
    character:Jump()
end)

disconnect() -- stop listening

Jump.pressed:once():andThen(function(event)
    print("jumped")
end)
```

#### The InputEvent object

Every callback receives an `InputEvent`:

| Field | Type | Description |
|-------|------|-------------|
| `binding` | `KeyCode \| UserInputType` | The specific binding that fired. |
| `phase` | `"pressed" \| "released" \| "changed"` | Which phase this is. |
| `position` | `Vector2?` | Screen position. Nil for non-positional inputs. |
| `delta` | `Vector2?` | Movement delta. Only on axis inputs. |
| `held` | `boolean` | True only on repeat-mode ticks. |
| `consumed` | `boolean` | Whether `:consume()` has been called. Readonly. |

**`:consume()`** marks the event as consumed. Knit checks this flag after each listener -- if consumed, the event skips any remaining subscribers. Use it when UI should eat an input before gameplay sees it.

---

### State Helpers

```lua
Jump:isHeld()          -- boolean -- is the action currently pressed
Jump:heldDuration()    -- number -- seconds held, 0 if not held

-- resolves after held for n seconds -- cancel on released for light/heavy pattern
Jump:holdFor(0.5):andThen(function()
    Combat:HeavyAttack()
end)

-- shorthand for pressed:once()
Jump:next():andThen(function(event)
    print("jumped")
end)

-- attach debug printers to all signals
Jump:log()
```

---

### Management

```lua
Jump:rebind({ Enum.KeyCode.X, Enum.KeyCode.ButtonB })  -- swap bindings live
Jump:disable()   -- silence without destroying
Jump:enable()    -- re-enable
Jump:destroy()   -- full teardown
```

---

### Promises

```lua
promise
    :andThen(function(value) end)   -- runs on resolve
    :catch(function(err) end)       -- runs on reject
    :cancel()                       -- cancels if pending -- cleans up subscriptions
    :await()                        -- yields thread, returns (ok, value)
```

---

### Context

```lua
Knit.context.push("gameplay")       -- activate a context
Knit.context.pop()                  -- remove the top, returns its name
Knit.context.peek()                 -- read top without removing -- string?
Knit.context.has("gameplay")        -- true if anywhere in the stack
Knit.context.stack()                -- full copy of the stack -- { string }
Knit.context.clear()                -- wipe everything

Knit.context.changed:connect(function(stack)
    print("top:", stack[#stack])    -- fires on every push/pop/clear
end)
```

---

### Raw Input

Bypasses the action system entirely. No context filter, no handle, fires on every matching input.

```lua
local disconnect = Knit.input.on(Enum.KeyCode.BackQuote, function(event)
    DebugPanel:Toggle()
end)

Knit.input.held(Enum.KeyCode.LeftShift)  -- boolean -- physical key state

disconnect()
```

---

### Helpers

#### Knit.race
```lua
Knit.race(signals: { Signal }) -> Promise
```
Resolves with the first signal that fires. Cancels all others immediately.

```lua
Knit.race({ Jump.pressed, Attack.pressed }):andThen(function(event)
    print("first:", tostring(event.binding))
end)
```

#### Knit.sequence
```lua
Knit.sequence(promises: { Promise }) -> Promise<{ any }>
```
Awaits each Promise left to right in strict order. Resolves with all values. Cancels all and rejects if any one fails.

```lua
Knit.sequence({
    Jump.pressed:once(),
    Attack.pressed:once(),
}):andThen(function()
    print("jump then attack -- in order")
end)
```

#### Knit.timeout
```lua
Knit.timeout(promise: Promise, seconds: number) -> Promise
```
Wraps any Promise with a deadline. Rejects with `"timeout"` if it doesn't resolve in time.

```lua
Knit.timeout(Jump.pressed:once(), 3.0)
    :andThen(function() print("in time") end)
    :catch(function(err) print(err) end)
```

#### Knit.buffer
```lua
Knit.buffer(action: ActionHandle, window: number) -> Promise
```
Opens a timed window on `action.pressed`. Resolves if the player presses within the window -- purpose-built for input buffering during hitstun or animation locks.

```lua
Combat.hitstunStarted:Connect(function()
    Knit.buffer(Attack, 0.3):andThen(function()
        Combat:QueueAttack()
    end)
end)
```

#### Knit.waitFor
```lua
Knit.waitFor(action: ActionHandle, phase: Phase?) -> Promise
```
One-shot wait on any action signal by phase name. Defaults to `"pressed"`.

```lua
Knit.waitFor(Jump, "released"):andThen(function()
    print("jump released")
end)
```

#### Knit.rebindAll
```lua
Knit.rebindAll(map: { [string]: { InputBinding } })
```
Bulk-rebinds multiple actions from a name-keyed table.

```lua
Knit.rebindAll({
    Jump   = { Enum.KeyCode.X },
    Attack = { Enum.UserInputType.MouseButton1 },
})
```

#### Knit.export / Knit.import
```lua
Knit.export() -> { [string]: { string } }
Knit.import(map: { [string]: { InputBinding } })
```
Serialize and restore all bindings. Safe to save to a datastore.

```lua
local saved = Knit.export()
DataStore:SetAsync(userId, saved)

-- next session
local saved = DataStore:GetAsync(userId)
if saved then Knit.import(saved) end
```

#### Knit.visualizer
```lua
Knit.visualizer() -> ScreenGui
```
Live input overlay in the top-right corner. Purple = pressed, green = triggered, yellow = axis delta, gray = idle. Remove before shipping.

```lua
Knit.visualizer()
```

---

### Registry

```lua
Knit.get("Jump")     -- ActionHandle? -- prefer passing the handle directly
Knit.action("Jump")  -- alias for Knit.get
Knit.remove("Jump")  -- destroy and unregister
Knit.clear()         -- destroy everything
```

---

## Patterns

### Charge Attack

Tap for light, hold for heavy. Cancel the charge Promise on release if it hasn't fired yet.

```lua
local chargePromise

Attack.pressed:connect(function()
    chargePromise = Attack:holdFor(0.6):andThen(function()
        Combat:HeavyAttack()
        chargePromise = nil
    end)
end)

Attack.released:connect(function()
    if chargePromise then
        chargePromise:cancel()
        chargePromise = nil
        Combat:LightAttack()
    end
end)
```

---

### Input Buffering

During hitstun, open a buffer window. If the player presses Attack within the window it queues -- if not, it closes cleanly with no side effects.

```lua
local buffered = false

Combat.hitstunStarted:Connect(function()
    Knit.buffer(Attack, 0.25):andThen(function()
        buffered = true
    end)
end)

Combat.hitstunEnded:Connect(function()
    if buffered then
        buffered = false
        Combat:Attack()
    end
end)
```

---

### Context Switching

Pushing `"menu"` silences all `"gameplay"` actions without touching any listeners.

```lua
local function openMenu()
    Knit.context.push("menu")
end

local function closeMenu()
    Knit.context.pop()
end

-- nested menus handled naturally
openMenu()          -- stack: ["gameplay", "menu"]
openInventory()     -- stack: ["gameplay", "menu", "inventory"]
closeInventory()    -- stack: ["gameplay", "menu"]
closeMenu()         -- stack: ["gameplay"]
```

---

### Settings Screen Rebinding

Export current bindings to prefill a UI, let the player edit, then import.

```lua
local function openSettings()
    local current = Knit.export()
    SettingsUI:Populate(current)
end

local function applySettings(newBindings)
    Knit.import(newBindings)
    DataStore:SetAsync(userId, newBindings)
end
```

---

### Tutorial Gating

Wait for the player to actually do the action before advancing. No timers, no polling.

```lua
local function runTutorial()
    UI:ShowPrompt("Press Space to jump")
    Knit.context.push("tutorial")

    local TutJump = Knit.define("TutJump", {
        bindings = { Enum.KeyCode.Space },
        contexts = { "tutorial" },
    })

    TutJump.pressed:once():andThen(function()
        Knit.context.pop()
        Knit.remove("TutJump")
        UI:HidePrompt()
    end)
end
```

---

## Combat Example

```lua
local Knit = require(game.ReplicatedStorage.Knit)

local LightAttack = Knit.define("LightAttack", {
    bindings = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR1 },
    contexts = { "gameplay" },
})

local HeavyAttack = Knit.define("HeavyAttack", {
    bindings = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonR2 },
    contexts = { "gameplay" },
})

local Block = Knit.define("Block", {
    bindings = { Enum.KeyCode.F, Enum.KeyCode.ButtonL1 },
    contexts = { "gameplay" },
})

local Dodge = Knit.define("Dodge", {
    contexts = { "gameplay" },
    mode     = "combo",
    sequence = { Enum.KeyCode.Q, Enum.KeyCode.Q },
    window   = 0.25,
})

local Parry = Knit.define("Parry", {
    bindings = { Enum.KeyCode.F, Enum.KeyCode.LeftShift },
    contexts = { "gameplay" },
    mode     = "shortcut",
})

local MenuConfirm = Knit.define("MenuConfirm", {
    bindings = { Enum.KeyCode.Return, Enum.KeyCode.ButtonA },
    contexts = { "menu" },
})

local attackPromise

LightAttack.pressed:connect(function(event)
    event:consume()
    attackPromise = LightAttack:holdFor(0.4):andThen(function()
        Combat:HeavyAttack()
        attackPromise = nil
    end)
end)

LightAttack.released:connect(function()
    if attackPromise then
        attackPromise:cancel()
        attackPromise = nil
        Combat:LightAttack()
    end
end)

Block.pressed:connect(function()  Combat:SetBlocking(true)  end)
Block.released:connect(function() Combat:SetBlocking(false) end)

Parry.triggered:connect(function(event)
    event:consume()
    Knit.timeout(
        Knit.race({ LightAttack.pressed, HeavyAttack.pressed }),
        0.2
    ):andThen(function()
        Combat:Parry()
    end)
end)

Dodge.triggered:connect(function()
    Combat:Dodge()
end)

Combat.hitstunStarted:Connect(function()
    Knit.buffer(LightAttack, 0.3):andThen(function()
        Combat:QueueAttack()
    end)
end)

MenuConfirm.pressed:connect(function(event)
    event:consume()
    Menu:Confirm()
end)

Knit.context.push("gameplay")
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
```

All types exported from `Knit/Types.lua` and re-exported by the main module.

---

## Contact

| Platform | Handle |
|---|---|
| Roblox | [Kr3ativeKrayon](https://www.roblox.com/users/1911367519/profile) |
| YouTube | [TotallyKr3ative](https://www.youtube.com/channel/UCpNZQoKVclQ74Pk5GmzdQDA) |
| X (Twitter) | [TotallyNotKr3ative](https://x.com/TheRealKr3ative) |
| Email | [TheRealKr3ative@gmail.com](mailto:TheRealKr3ative@gmail.com) |

---

*Last Updated: May 9, 2026*

---
