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
* [API Reference](#api-reference)
* [Knit.define](#notchdefine)
* [Action Handle](#action-handle)
* [Signals](#signals)
* [Promises](#promises)
* [Helpers](#helpers)
* [Context](#context)
* [Raw Input](#raw-input)
* [Combat Example](#combat-example)
* [Exported Types](#exported-types)
* [Contact](#contact)

---

## Features

* **Unified Action Registry:** Define once with `Knit.define`, get a handle back -- no string lookups ever again.
* **Auto-inferred Action Types:** Knit reads your bindings and infers `button` or `axis` automatically. No `type` field required.
* **Context Stack:** Push and pop named contexts. Actions only fire when their declared context is on top of the stack -- no manual disconnecting.
* **Combo Detection:** Sequential input sequences with configurable timing windows. Double-tap, directional inputs, anything.
* **Shortcut Detection:** Simultaneous key combinations that fire a single triggered signal.
* **Promise-based Async:** Every one-shot operation returns a cancellable Promise. Race inputs, sequence them, await them inside tasks.
* **Hold Detection:** `holdFor(n)` returns a Promise that resolves after an action has been continuously held for n seconds.
* **Raw Input Layer:** Bypass the action system entirely for low-level per-key listeners.
* **Runtime Rebinding:** Swap bindings on any action at runtime with `:rebind()`.
* **Enable / Disable:** Silence any action without destroying it.

---

## Installation

Place the Knit module into ReplicatedStorage or StarterPlayerScripts, then require it on the client. Knit is a client-only library -- never require it on the server.

```lua
local Knit = require(ReplicatedStorage.Knit)
```

---

## Quick Start

```lua
local Knit = require(ReplicatedStorage.Knit)

local Jump = Knit.define("Jump", {
    bindings = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA },
    contexts = { "gameplay" },
})

local Look = Knit.define("Look", {
    bindings = { Enum.UserInputType.MouseMovement },
    contexts = { "gameplay" },
})

local Dash = Knit.define("Dash", {
    bindings = { Enum.KeyCode.W },
    contexts = { "gameplay" },
    mode     = "combo",
    sequence = { Enum.KeyCode.W, Enum.KeyCode.W },
    window   = 0.3,
})

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

Knit.context.push("gameplay")
```

---

## Core Concepts

### Actions and Handles
`Knit.define` registers an action and returns a handle. Hold onto this handle -- it is the only way to interact with that action. There is no `Knit.action(name)` lookup by design. Define at the top of your module, use the handle everywhere.

### Type Inference
Knit reads your `bindings` array and automatically decides whether the action is a `button` or `axis`. `MouseMovement`, `MouseWheel`, `Thumbstick1`, and `Thumbstick2` produce an `axis` action. Everything else produces a `button`. You can override this with an explicit `mode` field.

### Context Stack
The context stack is a last-in-first-out list of named strings. An action with `contexts = { "gameplay" }` will only fire if `"gameplay"` appears anywhere in the active stack. Actions with no `contexts` field fire regardless of the current context. Push a context to activate it, pop it to return to the previous state.

### Combos vs Shortcuts
A `combo` fires `triggered` after a sequence of inputs land within a timing window. A `shortcut` fires `triggered` when all bindings are held simultaneously. Both are defined via `Knit.define` with the appropriate `mode` field.

### Promises
`signal:once()` returns a Promise that resolves the next time the signal fires, then auto-cancels. `Knit.race` resolves with the first signal that fires and cancels the rest. `Knit.sequence` resolves an array of Promises in order, left to right.

---

## API Reference

### Knit.define
```lua
Knit.define(name: string, config: ActionConfig) -> ActionHandle
```
Registers an action and returns its handle. Errors if the name is already registered.

| Field | Type | Description |
|-------|------|-------------|
| bindings | `{ KeyCode \| UserInputType }` | Input sources that trigger this action. |
| contexts | `{ string }?` | Active contexts required for this action to fire. Omit to fire in all contexts. |
| mode | `ActionMode?` | Override inferred type. One of `"button"`, `"axis"`, `"combo"`, `"shortcut"`. |
| sequence | `{ KeyCode \| UserInputType }?` | Required for `combo` mode. The ordered input sequence. |
| window | `number?` | Max seconds between inputs in a combo sequence. Default `0.4`. |

---

## Action Handle

The object returned by `Knit.define`. All interaction with an action goes through this handle.

### Signals

| Signal | Fires when | Action type |
|--------|-----------|-------------|
| `pressed` | A binding is pressed down | button |
| `released` | A binding is released | button |
| `held` | A binding is held (per-frame) | button |
| `moved` | An axis input produces a delta | axis |
| `triggered` | A combo or shortcut completes | combo, shortcut |

All signals expose `:connect(cb)` and `:once()`.

```lua
Jump.pressed:connect(function(event)
    event:consume()
end)

-- one-shot -- auto-disconnects after first fire
Jump.pressed:once():andThen(function(event)
    print("first jump")
end)
```

### State Helpers

```lua
-- is a binding currently held
Jump:isHeld() -- boolean

-- how long the action has been held
Jump:heldDuration() -- number (seconds), 0 if not held

-- resolves after the action has been held for n seconds continuously
Jump:holdFor(0.75):andThen(function()
    character:ChargeJump()
end)
```

### Management

```lua
-- swap bindings at runtime
Jump:rebind({ Enum.KeyCode.X, Enum.KeyCode.ButtonB })

-- silence without destroying
Jump:disable()
Jump:enable()

-- full cleanup
Jump:destroy()
```

---

## Promises

Every `:once()` call and helper method returns a Promise with the following surface:

```lua
promise
    :andThen(function(value) end)  -- runs on resolve
    :catch(function(err) end)      -- runs on reject
    :cancel()                      -- cancels if still pending
    :await()                       -- yields the current thread, returns (ok, value)
```

---

## Helpers

### Knit.race
```lua
Knit.race(signals: { Signal }) -> Promise
```
Resolves with the value of the first signal that fires. Cancels all other pending promises immediately.

```lua
Knit.race({ Jump.pressed, Dash.triggered }):andThen(function(event)
    print("first input won")
end)
```

### Knit.sequence
```lua
Knit.sequence(promises: { Promise }) -> Promise<{ any }>
```
Awaits each promise left to right. Resolves with an array of all values. Cancels all and rejects if any one rejects.

```lua
Knit.sequence({
    Jump.pressed:once(),
    Jump.pressed:once(),
}):andThen(function(results)
    print("jumped twice in order")
end)
```

### Knit.get
```lua
Knit.get(name: string) -> ActionHandle?
```
Retrieves a registered action by name. Returns nil if not found.

### Knit.remove
```lua
Knit.remove(name: string)
```
Destroys and unregisters a named action.

### Knit.clear
```lua
Knit.clear()
```
Destroys all actions, clears all raw listeners, and resets the context stack.

---

## Context

```lua
-- push a context onto the stack
Knit.context.push("gameplay")

-- pop the top context
Knit.context.pop()

-- read the top context without removing it
Knit.context.peek() -- string?

-- wipe the entire stack
Knit.context.clear()

-- get a copy of the full stack
Knit.context.stack() -- { string }
```

---

## Raw Input

Raw listeners bypass the action registry entirely. They have no context filter, no handle, and fire on every matching input regardless of game state. Use for debug tools, global hotkeys, or editor shortcuts.

```lua
-- returns a disconnect function
local disconnect = Knit.input.on(Enum.KeyCode.Tab, function(event)
    DebugPanel:Toggle()
end)

-- check if a binding is currently held
Knit.input.held(Enum.KeyCode.LeftShift) -- boolean

-- stop listening
disconnect()
```

---

## Combat Example

```lua
local Knit   = require(ReplicatedStorage.Knit)
local Promise = require(ReplicatedStorage.Knit.Promise)

-- actions
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
    bindings  = { Enum.KeyCode.Q },
    contexts  = { "gameplay" },
    mode      = "combo",
    sequence  = { Enum.KeyCode.Q, Enum.KeyCode.Q },
    window    = 0.25,
})

local Parry = Knit.define("Parry", {
    bindings = { Enum.KeyCode.F, Enum.KeyCode.LeftShift },
    contexts = { "gameplay" },
    mode     = "shortcut",
})

local Confirm = Knit.define("Confirm", {
    bindings = { Enum.KeyCode.Return, Enum.KeyCode.ButtonA },
    contexts = { "menu" },
})

-- light attack
LightAttack.pressed:connect(function(event)
    event:consume()
    Combat:LightAttack()
end)

-- hold for heavy
HeavyAttack:holdFor(0.4):andThen(function()
    Combat:HeavyAttack()
end)

-- block while held
Block.pressed:connect(function()
    Combat:SetBlocking(true)
end)

Block.released:connect(function()
    Combat:SetBlocking(false)
end)

-- parry window -- race the next input against a short timer
Parry.triggered:connect(function(event)
    event:consume()

    Knit.race({
        LightAttack.pressed,
        HeavyAttack.pressed,
    }):andThen(function()
        Combat:Parry()
    end):cancel() -- cancel race after 0.2s window

    task.delay(0.2, function()
        -- window expired
    end)
end)

-- double-tap dodge
Dodge.triggered:connect(function()
    Combat:Dodge()
end)

-- menu confirm -- only fires in menu context
Confirm.pressed:connect(function(event)
    event:consume()
    Menu:Confirm()
end)

-- context management
local function enterCombat()
    Knit.context.push("gameplay")
end

local function openMenu()
    Knit.context.push("menu") -- gameplay actions go silent
end

local function closeMenu()
    Knit.context.pop() -- gameplay resumes
end
```

---

## Exported Types

```lua
export type ActionMode    = "button" | "axis" | "combo" | "shortcut"
export type InputBinding  = Enum.KeyCode | Enum.UserInputType
export type Phase         = "pressed" | "released" | "changed"

export type ActionConfig  = {
    bindings:  { InputBinding },
    contexts:  { string }?,
    mode:      ActionMode?,
    sequence:  { InputBinding }?,
    window:    number?,
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
    rebind:       (self: ActionHandle, bindings: { InputBinding }) -> (),
    enable:       (self: ActionHandle) -> (),
    disable:      (self: ActionHandle) -> (),
    destroy:      (self: ActionHandle) -> (),
}
```

All types are exported from `Knit/Types.lua` and re-exported by the main module.

---

## Contact

| Platform | Handle |
|---|---|
| Roblox | [Kr3ativeKrayon](https://www.roblox.com/users/1911367519/profile) |
| YouTube | [TotallyKr3ative](https://www.youtube.com/channel/UCpNZQoKVclQ74Pk5GmzdQDA) |
| X (Twitter) | [TotallyNotKr3ative](https://x.com/TheRealKr3ative) |
| Email | [TheRealKr3ative@gmail.com](mailto:TheRealKr3ative@gmail.com) |

---

*Last Updated: May 8, 2026*
