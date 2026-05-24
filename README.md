<div align="center">

# Mitt

**Full-stack input library for Roblox**

[![Version](https://img.shields.io/badge/version-2.0.0-6C3EF4?style=flat-square&logoColor=white)](https://github.com/NotKisoMomo/Mitt)
[![Stability](https://img.shields.io/badge/stability-stable-22c55e?style=flat-square)](https://github.com/NotKisoMomo/Mitt)
[![License](https://img.shields.io/badge/license-MIT-6C3EF4?style=flat-square)](https://github.com/NotKisoMomo/Mitt/blob/main/LICENSE)
[![Luau](https://img.shields.io/badge/luau-typed-6C3EF4?style=flat-square)](https://luau-lang.org)
[![Roblox](https://img.shields.io/badge/roblox-client--only-e11d48?style=flat-square)](https://create.roblox.com)
[![Built by Plinko Labs](https://img.shields.io/badge/built%20by-Plinko%20Labs-6C3EF4?style=flat-square)](https://github.com/NotKisoMomo)

</div>

---

Mitt is a full-stack input library for Roblox. It provides a unified action registry, multi-driver backend (UIS / IAS / CAS), context-aware filtering, combo and shortcut detection, Promise-based async flows, session-based state containers, a mobile touch layer with icon library, and raw input access -- all in one client-side module.

---

## Table of Contents

* [Features](#features)
* [Installation](#installation)
* [Quick Start](#quick-start)
* [Core Concepts](#core-concepts)
  * [How Mitt Thinks About Input](#how-mitt-thinks-about-input)
  * [Actions and Handles](#actions-and-handles)
  * [Drivers](#drivers)
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
  * [Touch](#touch)
  * [Icons](#icons)
  * [Platform](#platform)
  * [Async Operators](#async-operators)
  * [Raw Input](#raw-input)
  * [Helpers](#helpers)
  * [Registry](#registry)
  * [Debug](#debug)
* [Patterns](#patterns)
  * [Charge Attack](#charge-attack)
  * [Input Buffering](#input-buffering)
  * [Context Switching](#context-switching)
  * [Session-driven Combat State](#session-driven-combat-state)
  * [IAS Direction2D Movement](#ias-direction2d-movement)
  * [IAS Analog Trigger](#ias-analog-trigger)
  * [Mobile Layout with Icons](#mobile-layout-with-icons)
  * [Platform-adaptive Bindings](#platform-adaptive-bindings)
  * [Settings Screen Rebinding](#settings-screen-rebinding)
  * [Tutorial Gating](#tutorial-gating)
* [Combat Example](#combat-example)
* [Exported Types](#exported-types)
* [Changelog](#changelog)
* [Contact](#contact)

---

## Features

**Core**
* **Unified Action Registry:** Define once with `Mitt.define`, get a handle back. No string lookups, no global tables.
* **Multi-driver Backend:** `"uis"` (default), `"ias"` (native IAS instances), or `"cas"` (ContextActionService) -- per-action, all returning identical handles.
* **Auto-inferred Action Types:** Mitt reads your `bindings` and decides `button` vs `axis` automatically.
* **Context Stack:** Push `"menu"` and gameplay actions go silent. Pop it and everything resumes -- no listener changes.

**Action Modes**
* **Button / Axis / Combo / Shortcut** -- original modes, unchanged.
* **Hold:** Fires `triggered` only after continuously held for `holdTime` seconds.
* **DoubleTap:** Two presses within `window` -- no sequence config needed.
* **Charge:** Built-in charge mode -- fires `charged` each tick with normalized `0-1` progress, `released` carries final level.
* **Mash:** Counts rapid presses in a window, fires `triggered` with a `count` field when threshold met.
* **LongPress:** Mobile-first -- fires after `n` seconds held, cancels on early release.
* **Gesture:** Directional swipe detection on touch/mouse -- up/down/left/right/diagonal.
* **Sequence:** Alias for combo with added `stepFired` signal on each valid step.

**IAS Driver**
* Creates real `InputAction`, `InputContext`, `InputBinding` instances under the hood.
* Full `InputActionType` support: `Bool`, `Direction1D`, `Direction2D`, `Direction3D`, `ViewportPosition`.
* Composite direction bindings: WASD → dir2d, trigger analog, 6DOF keys.
* Analog threshold control, response curves, axis scale, modifier keys, clamp magnitude.
* `stateChanged`, `bindingsChanged` signals. `:getState()`, `:getBindings()`, `:fire()`.
* Context priority and sink fully wired to native `InputContext`.

**CAS Driver**
* Full CAS bind/unbind lifecycle managed by Mitt.
* `casPriority`, `processSink`, and `mobile` callback exposed on config.

**Mobile Touch Layer**
* `Mitt.touch.layout()` -- declare positions, Mitt creates and wires buttons.
* `Mitt.touch.bind()` -- manually wire your own button instances.
* `Mitt.touch.register()` -- self-registration by action name, UI and input fully decoupled.
* Context-aware visibility -- buttons auto-show/hide with their action's context.
* Draggable layout with `Mitt.touch.exportLayout()` / `importLayout()` for persistence.
* `Mitt.touch.theme()` -- configure idle/pressed colors, corner radius, icon tint, label font.

**Icon Library**
* `Mitt.Icons` -- flat table of named asset ID tokens covering combat, movement, interaction, UI, weapons, vehicle, and ability slots.
* `Mitt.Icons.Custom(assetId)` -- bring your own ID into the same pipeline.

**Async Operators**
* `Mitt.gate`, `Mitt.debounce`, `Mitt.throttle`, `Mitt.map`, `Mitt.after`, `Mitt.any`, `Mitt.repeat`.

**Platform**
* `Mitt.platform.current` -- reactive, fires `changed` on device switch.
* Per-binding `platforms` filter -- bindings only activate on matching hardware.
* `preferredInput` integration -- auto-promotes correct bindings on device switch.

**Sessions**
* Named state containers. `onChange`, `onAnyChange`, `onBatch`. Derive, link, persist, schema-type.

**Rebinding & Profiles**
* Named profiles: `exportProfile`, `importProfile`, `diffBindings`, `resetToDefaults`.
* Conflict detection: `Mitt.getConflicts()`. Binding lock: `action:lockBinding()`.

**Debug & Tooling**
* `Mitt.record()` / `Mitt.replay()` -- deterministic input recording and replay.
* `Mitt.audit()` -- report of unused, unbound, and conflicting actions.
* `Mitt.profile()` -- signal dispatch latency per action.
* `Mitt.visualizer()` -- live overlay with context stack, session state, and binding conflicts.
* Action tags: `tags = { "combat" }`, `Mitt.getByTag("combat")`.

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

Without Mitt, input in Roblox looks like this:

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

Once you have 20 actions, multiple game states, combos, held detection, rebinding, and transient booleans scattered across modules -- it becomes unmaintainable.

Mitt solves both sides. Actions replace the `InputBegan` wall. Sessions replace the scattered state variables.

---

### Actions and Handles

`Mitt.define` registers an action and returns a handle. Hold onto it -- it is the only way to interact with that action. No retrieval-by-string by design.

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

### Drivers

Every action has a `driver` field that controls which native system owns raw input registration.

| Driver | Backend | When to use |
|--------|---------|-------------|
| `"uis"` | UserInputService (default) | Most cases -- no instances needed |
| `"ias"` | InputAction/Context/Binding instances | Cross-platform, analog, directional, touch UIButton |
| `"cas"` | ContextActionService | Legacy CAS integration, mobile button callbacks |

The handle you get back is identical regardless of driver -- same signals, sessions, combo engine, everything.

---

### Type Inference

Mitt reads your `bindings` and classifies the action:

| Binding | Inferred type |
|---------|--------------|
| Any `KeyCode` except thumbsticks | `button` |
| `MouseButton1/2/3` | `button` |
| `MouseMovement`, `MouseWheel` | `axis` |
| `Thumbstick1`, `Thumbstick2` | `axis` |
| `Gyro`, `Accelerometer` | `axis` |

Override with an explicit `mode` field if needed.

---

### Context Stack

LIFO list of named strings. An action fires only if its `contexts` contains something in the stack. Actions with no `contexts` always fire.

```lua
Mitt.context.push("gameplay")
Mitt.context.push("menu")
-- both gameplay and menu actions fire

Mitt.context.pop()
-- back to gameplay only
```

---

### Signals vs Promises

**Signals** -- persistent, fires every time.

```lua
Jump.pressed:connect(function(event)
    character:Jump()
end)
```

**Promises** -- one-shot, self-cleaning.

```lua
Jump.pressed:once():andThen(function(event)
    print("first jump")
end)
```

---

### Sessions

Named state containers that replace scattered module-level variables. Every key change fires a signal.

```lua
local CombatState = Mitt.createSession("Combat", {
    charging  = false,
    blocking  = false,
    comboStep = 0,
})
```

---

## API Reference

### Mitt.define

```lua
Mitt.define(name: string, config: ActionConfig) -> ActionHandle
```

Registers an action and returns its handle. Errors if `name` is already registered.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `bindings` | `{ InputBinding \| BindingConfig }` | required | Input sources. Omit for combos. |
| `contexts` | `{ string }?` | nil | Active contexts. Omit to always fire. |
| `driver` | `DriverMode?` | `"uis"` | `"uis"` \| `"ias"` \| `"cas"` |
| `mode` | `ActionMode?` | inferred | Override action mode. |
| `actionType` | `ActionType?` | `"bool"` | IAS only: `"bool"` \| `"dir1d"` \| `"dir2d"` \| `"dir3d"` \| `"viewport"` |
| `sequence` | `{ InputBinding }?` | nil | Combo/sequence mode steps. |
| `window` | `number?` | `0.4` | Combo timing window in seconds. |
| `holdTime` | `number?` | `0.5` | Seconds for `hold`/`longpress` mode. |
| `mashThreshold` | `number?` | `5` | Press count for `mash` mode. |
| `deadzone` | `number \| DeadzoneConfig?` | `0.0` | Flat magnitude or `{ inner, outer }`. |
| `repeatInterval` | `number?` | nil | Held re-fire interval. |
| `priority` | `number?` | nil | IAS/CAS bind priority. |
| `sink` | `boolean?` | false | IAS: block lower-priority contexts. |
| `platforms` | `{ string }?` | nil | `"keyboard"` \| `"gamepad"` \| `"touch"` filter. |
| `tags` | `{ string }?` | nil | Tag grouping for `Mitt.getByTag`. |
| `casPriority` | `number?` | nil | CAS only: bind priority. |
| `processSink` | `boolean?` | false | CAS only: sink gameProcessed. |
| `mobile` | `((UserInputState) -> ())?` | nil | CAS only: touch button callback. |

**BindingConfig** (IAS driver, object instead of KeyCode):

| Field | Type | Description |
|-------|------|-------------|
| `keyCode` | `KeyCode \| UserInputType` | Primary key |
| `primaryModifier` | `KeyCode?` | Required held modifier |
| `secondaryModifier` | `KeyCode?` | Second required modifier |
| `pressedThreshold` | `number?` | Analog press threshold |
| `releasedThreshold` | `number?` | Analog release threshold |
| `responseCurve` | `number?` | Easing on analog value |
| `scale` | `number?` | Scalar multiplier |
| `vector2Scale` | `Vector2?` | Per-axis 2D scale |
| `vector3Scale` | `Vector3?` | Per-axis 3D scale |
| `clampMagnitude` | `boolean?` | Normalize composite input |
| `pointerIndex` | `number?` | Multi-touch finger index |
| `uiButton` | `GuiButton?` | Touch button (bool type only) |
| `up/down/left/right` | `KeyCode?` | Composite dir2d/dir1d keys |
| `forward/backward` | `KeyCode?` | Composite dir3d keys |
| `invertAxis` | `boolean?` | Flip axis sign |
| `platforms` | `{ string }?` | Per-binding platform filter |

---

### Action Handle

The object returned by `Mitt.define`.

---

### Signals

| Signal | Fires when | Modes |
|--------|-----------|-------|
| `pressed` | Binding goes down | `button`, `shortcut`, `hold`, `charge`, `longpress`, `doubletap` |
| `released` | Binding goes up | `button`, `charge` |
| `held` | Binding held per Heartbeat | `button` |
| `moved` | Axis delta | `axis`, `dir2d`, `dir3d`, `viewport` |
| `triggered` | Combo/shortcut/hold/mash completes | `combo`, `sequence`, `shortcut`, `hold`, `mash`, `doubletap`, `gesture` |
| `charged` | Each tick during charge -- value `0-1` | `charge` |
| `stateChanged` | Any value change | `ias` driver all types |
| `stepFired` | Each valid combo step | `combo`, `sequence` |
| `canceled` | Combo/charge broken early | `combo`, `sequence`, `charge` |
| `conflicted` | Binding claimed by higher-priority action | all |
| `bindingsChanged` | Binding added/removed at runtime | `ias` driver |
| `enabledChanged` | Action enabled state flips | all |
| `contextChanged` | Action's context pushed/popped | all |

```lua
local disconnect = Jump.pressed:connect(function(event)
    character:Jump()
end)

disconnect()

Jump.charged:connect(function(progress)
    ChargeBar:SetFill(progress)
end)

Move.stateChanged:connect(function(value)
    -- Vector2 for dir2d
    Animator:SetBlend(value.Magnitude)
end)
```

#### InputEvent fields

| Field | Type | Description |
|-------|------|-------------|
| `binding` | `KeyCode \| UserInputType` | Specific binding that fired |
| `phase` | `"pressed" \| "released" \| "changed"` | Input phase |
| `position` | `Vector2?` | Screen position |
| `delta` | `Vector2?` | Movement delta |
| `held` | `boolean` | True on repeat-mode ticks |
| `consumed` | `boolean` | Readonly -- whether consumed |

**`:consume()`** stops propagation to remaining subscribers.

---

### State Helpers

```lua
Jump:isHeld()             -- boolean
Jump:heldDuration()       -- number
Jump:getCharge()          -- number -- 0-1, 0 if not charging
Jump:getState()           -- boolean | number | Vector2 | Vector3  (ias driver)
Jump:getBindings()        -- { InputBinding }  (ias driver)
Jump:getPriority()        -- number
Jump:setPriority(n)       -- void
Jump:getContext()         -- { string }
Jump:transferContext(name) -- void

Jump:holdFor(0.5):andThen(function() end)
Jump:next():andThen(function(event) end)
Jump:history(10)          -- last 10 InputEvents
Jump:log()
```

---

### Management

```lua
Jump:rebind({ Enum.KeyCode.X })
Jump:lockBinding()
Jump:enable()
Jump:disable()
Jump:mute()
Jump:unmute()
Jump:fire(state)          -- programmatic trigger
Jump:simulate("pressed")  -- full synthetic event through pipeline
Jump:clone("JumpAlt", { contexts = { "vehicle" } })
Jump:destroy()
```

---

### Promises

```lua
promise
    :andThen(function(value) end)
    :catch(function(err) end)
    :cancel()
    :await()
```

---

### Context

```lua
Mitt.context.push("gameplay")
Mitt.context.push("menu", { priority = 200, sink = true })
Mitt.context.pushGroup({ "gameplay", "vehicles" })
Mitt.context.pop()
Mitt.context.peek()
Mitt.context.has("gameplay")
Mitt.context.stack()
Mitt.context.clear()
Mitt.context.snapshot()
Mitt.context.restore(snap)
Mitt.context.guard("gameplay", function() return character ~= nil end)

Mitt.context.onPush("menu", function() end)
Mitt.context.onPop("menu", function() end)
Mitt.context.changed:connect(function(stack) end)
Mitt.context.actionsChanged:connect(function() end)  -- ias driver

Mitt.context.getActions("gameplay")  -- { ActionHandle }
```

---

### Sessions API

#### Mitt.createSession

```lua
Mitt.createSession(name: string, defaults: { [string]: any }) -> SessionHandle
```

#### Mitt.getSession / modifySession / removeSession

```lua
Mitt.getSession(name)
Mitt.modifySession(name, data)
Mitt.removeSession(name)
```

#### SessionHandle methods

```lua
session:get(key)
session:set(key, value)
session:patch(data)
session:toggle(key)
session:increment(key, amount?)
session:decrement(key, amount?)
session:reset()
session:derive(key, fn)          -- computed value, auto-updates on dependency change
session:link(other, keyA, keyB)  -- bidirectional key sync between sessions
session:persist(key, datastore)  -- auto-save key to DataStore on change
session:history(key, n?)         -- last n values for key
session:onChange(key, cb)
session:onAnyChange(cb)
session:onBatch(keys, cb)        -- fires once after all listed keys change in same frame
session:snapshot()
session:destroy()
```

---

### Touch

```lua
Mitt.touch.bind(action, button)          -- wire existing GuiButton
Mitt.touch.unbind(action)
Mitt.touch.register(actionName, button)  -- self-registration by name
Mitt.touch.unregister(actionName)

Mitt.touch.layout({
    [Jump] = {
        position      = UDim2.fromScale(0.88, 0.72),
        size          = UDim2.fromOffset(72, 72),
        icon          = Mitt.Icons.Jump,
        label         = "Jump",
        draggable     = true,
    },
    [Attack] = {
        position = UDim2.fromScale(0.78, 0.82),
        size     = UDim2.fromOffset(72, 72),
        icon     = Mitt.Icons.Attack,
    },
})

Mitt.touch.theme({
    idle         = { color = Color3.fromHex("#1a1a1a"), transparency = 0.3 },
    pressed      = { color = Color3.fromHex("#6C3EF4"), transparency = 0.1 },
    cornerRadius = UDim.new(1, 0),
    iconColor    = Color3.fromHex("#ffffff"),
    labelFont    = Enum.Font.GothamBold,
    labelSize    = 10,
})

Mitt.touch.show()
Mitt.touch.hide()
Mitt.touch.setIcon(action, icon)
Mitt.touch.getButton(action)       -- ImageButton instance
Mitt.touch.exportLayout()          -- serializable positions table
Mitt.touch.importLayout(data)
Mitt.touch.reset()                 -- restore default positions
```

Buttons auto-show/hide when their action's context becomes active/inactive. Labels auto-update on rebind.

---

### Icons

```lua
Mitt.Icons.Jump         Mitt.Icons.Sprint       Mitt.Icons.Crouch
Mitt.Icons.Roll         Mitt.Icons.Slide        Mitt.Icons.Climb

Mitt.Icons.Attack       Mitt.Icons.HeavyAttack  Mitt.Icons.Block
Mitt.Icons.Dodge        Mitt.Icons.Parry        Mitt.Icons.Combo
Mitt.Icons.Charge       Mitt.Icons.Ultimate     Mitt.Icons.Dash

Mitt.Icons.Interact     Mitt.Icons.Pickup       Mitt.Icons.Drop
Mitt.Icons.Use          Mitt.Icons.Inspect      Mitt.Icons.Talk

Mitt.Icons.Confirm      Mitt.Icons.Cancel       Mitt.Icons.Back
Mitt.Icons.Menu         Mitt.Icons.Map          Mitt.Icons.Inventory
Mitt.Icons.Settings     Mitt.Icons.Pause

Mitt.Icons.Shoot        Mitt.Icons.Reload       Mitt.Icons.Aim
Mitt.Icons.Swap         Mitt.Icons.Throw        Mitt.Icons.Holster

Mitt.Icons.Accelerate   Mitt.Icons.Brake        Mitt.Icons.Boost
Mitt.Icons.Horn         Mitt.Icons.Exit

Mitt.Icons.Ability1     Mitt.Icons.Ability2     Mitt.Icons.Ability3
Mitt.Icons.Ability4     Mitt.Icons.Ability5     Mitt.Icons.Ability6

Mitt.Icons.Custom(assetId)  -- wrap your own asset ID into the pipeline
```

---

### Platform

```lua
Mitt.platform.current   -- "keyboard" | "gamepad" | "touch"

Mitt.platform.onSwitch(function(new, prev)
    print("switched from", prev, "to", new)
end)

Mitt.platform.changed:connect(function(platform) end)
```

Per-binding `platforms` filter:

```lua
local Sprint = Mitt.define("Sprint", {
    bindings = {
        { keyCode = Enum.KeyCode.LeftShift, platforms = { "keyboard" } },
        { keyCode = Enum.KeyCode.ButtonL3,  platforms = { "gamepad"  } },
    },
    contexts = { "gameplay" },
})
```

---

### Async Operators

```lua
Mitt.gate(action, predicate)         -- signal filtered by predicate
Mitt.debounce(action, seconds)       -- won't re-fire within n seconds of last fire
Mitt.throttle(action, seconds)       -- at most once per n seconds
Mitt.map(action, fn)                 -- transform InputEvent before subscribers see it
Mitt.after(action, n)                -- resolves on the nth fire only
Mitt.any(signals)                    -- resolves with all signals firing same frame
Mitt.repeat(action, interval, max?)  -- programmatic repeat loop, returns Promise
```

---

### Raw Input

```lua
local disconnect = Mitt.input.on(Enum.KeyCode.BackQuote, function(event)
    DebugPanel:Toggle()
end)

Mitt.input.held(Enum.KeyCode.LeftShift)

disconnect()
```

---

### Helpers

#### Mitt.race
```lua
Mitt.race(signals: { Signal }) -> Promise
```

#### Mitt.sequence
```lua
Mitt.sequence(promises: { Promise }) -> Promise<{ any }>
```

#### Mitt.timeout
```lua
Mitt.timeout(promise: Promise, seconds: number) -> Promise
```

#### Mitt.buffer
```lua
Mitt.buffer(action: ActionHandle, window: number) -> Promise
```

#### Mitt.waitFor
```lua
Mitt.waitFor(action: ActionHandle, phase: Phase?) -> Promise
```

#### Mitt.rebindAll
```lua
Mitt.rebindAll(map: { [string]: { InputBinding } })
```

#### Mitt.export / Mitt.import
```lua
Mitt.export() -> { [string]: { string } }
Mitt.import(map: { [string]: { InputBinding } })
```

#### Mitt.exportProfile / Mitt.importProfile
```lua
Mitt.exportProfile(name: string)
Mitt.importProfile(name: string)
Mitt.diffBindings(profileA: string, profileB: string) -> { [string]: any }
Mitt.resetToDefaults()
```

#### Mitt.getConflicts
```lua
Mitt.getConflicts() -> { [string]: { ActionHandle } }
```

#### Mitt.getByTag
```lua
Mitt.getByTag(tag: string) -> { ActionHandle }
```

#### Mitt.visualizer
```lua
Mitt.visualizer() -> ScreenGui
```

Live overlay -- purple = pressed, green = triggered, yellow = axis delta, gray = idle. Shows context stack, session state, and binding conflicts. Remove before shipping.

---

### Registry

```lua
Mitt.get("Jump")
Mitt.action("Jump")
Mitt.remove("Jump")
Mitt.clear()
```

---

### Debug

```lua
Mitt.record()                    -- start recording input events
Mitt.stopRecord() -> Recording   -- stop and return recording
Mitt.replay(recording)           -- replay deterministically
Mitt.assert(action, phase, timeout?) -> Promise
Mitt.audit() -> AuditReport      -- unused, unbound, conflicting actions
Mitt.profile() -> ProfileReport  -- signal dispatch latency per action
```

---

## Patterns

### Charge Attack

```lua
local CombatState = Mitt.createSession("Combat", { charging = false })
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

```lua
local CombatState = Mitt.createSession("Combat", { buffered = false })

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
Knit.context.push("gameplay")       -- stack: ["gameplay"]
openMenu()                           -- stack: ["gameplay", "menu"]
openInventory()                      -- stack: ["gameplay", "menu", "inventory"]
closeInventory()                     -- stack: ["gameplay", "menu"]
closeMenu()                          -- stack: ["gameplay"]
```

---

### Session-driven Combat State

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
```

---

### IAS Direction2D Movement

```lua
local Move = Mitt.define("Move", {
    driver     = "ias",
    actionType = "dir2d",
    contexts   = { "gameplay" },
    bindings   = {
        {
            up    = Enum.KeyCode.W,
            down  = Enum.KeyCode.S,
            left  = Enum.KeyCode.A,
            right = Enum.KeyCode.D,
            clampMagnitude = true,
        },
        { keyCode = Enum.KeyCode.Thumbstick1 },
    },
})

Move.stateChanged:connect(function(value)
    controller:ApplyInput(value)
    Animator:SetMoveBlend(value.Magnitude)
end)
```

---

### IAS Analog Trigger

```lua
local SoftAim = Mitt.define("SoftAim", {
    driver     = "ias",
    actionType = "dir1d",
    contexts   = { "gameplay" },
    bindings   = {
        {
            keyCode           = Enum.KeyCode.ButtonL2,
            pressedThreshold  = 0.3,
            releasedThreshold = 0.15,
            responseCurve     = 0.8,
        },
    },
})

SoftAim.pressed:connect(function()  camera:StartADS() end)
SoftAim.released:connect(function() camera:StopADS()  end)
SoftAim.stateChanged:connect(function(value)
    camera:SetADSBlend(value)
end)
```

---

### Mobile Layout with Icons

```lua
Mitt.touch.theme({
    idle         = { color = Color3.fromHex("#111111"), transparency = 0.25 },
    pressed      = { color = Color3.fromHex("#6C3EF4"), transparency = 0.0  },
    cornerRadius = UDim.new(1, 0),
    iconColor    = Color3.fromHex("#ffffff"),
    labelFont    = Enum.Font.GothamBold,
    labelSize    = 9,
})

Mitt.touch.layout({
    [Jump] = {
        position  = UDim2.fromScale(0.88, 0.72),
        size      = UDim2.fromOffset(72, 72),
        icon      = Mitt.Icons.Jump,
        label     = "Jump",
        draggable = true,
    },
    [Attack] = {
        position = UDim2.fromScale(0.78, 0.82),
        size     = UDim2.fromOffset(72, 72),
        icon     = Mitt.Icons.Attack,
    },
    [Dodge] = {
        position = UDim2.fromScale(0.68, 0.72),
        size     = UDim2.fromOffset(64, 64),
        icon     = Mitt.Icons.Dodge,
    },
})

local saved = DataStore:GetAsync(userId .. "_layout")
if saved then
    Mitt.touch.importLayout(saved)
end

Mitt.touch.exportLayout()
```

---

### Platform-adaptive Bindings

```lua
local Sprint = Mitt.define("Sprint", {
    contexts = { "gameplay" },
    bindings = {
        { keyCode = Enum.KeyCode.LeftShift, platforms = { "keyboard" } },
        { keyCode = Enum.KeyCode.ButtonL3,  platforms = { "gamepad"  } },
    },
})

Mitt.platform.onSwitch(function(new)
    if new == "touch" then
        Mitt.touch.show()
    else
        Mitt.touch.hide()
    end
end)
```

---

### Settings Screen Rebinding

```lua
local function openSettings()
    SettingsUI:Populate(Mitt.export())
end

local function applySettings(newBindings)
    Mitt.import(newBindings)
    Mitt.exportProfile("custom")
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
    driver   = "ias",
    contexts = { "gameplay" },
    bindings = {
        {
            keyCode         = Enum.KeyCode.F,
            primaryModifier = Enum.KeyCode.LeftShift,
        },
    },
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
export type DriverMode    = "uis" | "ias" | "cas"
export type ActionMode    = "button" | "axis" | "combo" | "sequence" | "shortcut"
                          | "hold" | "doubletap" | "charge" | "mash" | "longpress"
                          | "gesture"
export type ActionType    = "bool" | "dir1d" | "dir2d" | "dir3d" | "viewport"
export type InputBinding  = Enum.KeyCode | Enum.UserInputType
export type Phase         = "pressed" | "released" | "changed"

export type DeadzoneConfig = {
    inner: number,
    outer: number,
}

export type BindingConfig = {
    keyCode:           InputBinding?,
    primaryModifier:   Enum.KeyCode?,
    secondaryModifier: Enum.KeyCode?,
    pressedThreshold:  number?,
    releasedThreshold: number?,
    responseCurve:     number?,
    scale:             number?,
    vector2Scale:      Vector2?,
    vector3Scale:      Vector3?,
    clampMagnitude:    boolean?,
    pointerIndex:      number?,
    uiButton:          GuiButton?,
    up:                Enum.KeyCode?,
    down:              Enum.KeyCode?,
    left:              Enum.KeyCode?,
    right:             Enum.KeyCode?,
    forward:           Enum.KeyCode?,
    backward:          Enum.KeyCode?,
    invertAxis:        boolean?,
    platforms:         { string }?,
}

export type ActionConfig = {
    bindings:        { InputBinding | BindingConfig },
    contexts:        { string }?,
    driver:          DriverMode?,
    mode:            ActionMode?,
    actionType:      ActionType?,
    sequence:        { InputBinding }?,
    window:          number?,
    holdTime:        number?,
    mashThreshold:   number?,
    deadzone:        number | DeadzoneConfig?,
    repeatInterval:  number?,
    priority:        number?,
    sink:            boolean?,
    platforms:       { string }?,
    tags:            { string }?,
    casPriority:     number?,
    processSink:     boolean?,
    mobile:          ((UserInputState) -> ())?,
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
    pressed:         Signal<InputEvent>,
    released:        Signal<InputEvent>,
    held:            Signal<InputEvent>,
    moved:           Signal<InputEvent>,
    triggered:       Signal<InputEvent>,
    charged:         Signal<number>,
    stateChanged:    Signal<any>,
    stepFired:       Signal<number>,
    canceled:        Signal<()>,
    conflicted:      Signal<ActionHandle>,
    bindingsChanged: Signal<()>,
    enabledChanged:  Signal<boolean>,
    contextChanged:  Signal<string>,

    isHeld:           (self: ActionHandle) -> boolean,
    heldDuration:     (self: ActionHandle) -> number,
    getCharge:        (self: ActionHandle) -> number,
    getState:         (self: ActionHandle) -> any,
    getBindings:      (self: ActionHandle) -> { Instance },
    getPriority:      (self: ActionHandle) -> number,
    setPriority:      (self: ActionHandle, n: number) -> (),
    getContext:       (self: ActionHandle) -> { string },
    transferContext:  (self: ActionHandle, name: string) -> (),
    holdFor:          (self: ActionHandle, seconds: number) -> Promise<InputEvent>,
    next:             (self: ActionHandle) -> Promise<InputEvent>,
    history:          (self: ActionHandle, n: number?) -> { InputEvent },
    log:              (self: ActionHandle) -> (),
    rebind:           (self: ActionHandle, bindings: { InputBinding }) -> (),
    lockBinding:      (self: ActionHandle) -> (),
    enable:           (self: ActionHandle) -> (),
    disable:          (self: ActionHandle) -> (),
    mute:             (self: ActionHandle) -> (),
    unmute:           (self: ActionHandle) -> (),
    fire:             (self: ActionHandle, state: any?) -> (),
    simulate:         (self: ActionHandle, phase: Phase) -> (),
    clone:            (self: ActionHandle, name: string, overrides: ActionConfig?) -> ActionHandle,
    destroy:          (self: ActionHandle) -> (),
}

export type SessionHandle = {
    get:         (self: SessionHandle, key: string) -> any,
    set:         (self: SessionHandle, key: string, value: any) -> (),
    patch:       (self: SessionHandle, data: { [string]: any }) -> (),
    toggle:      (self: SessionHandle, key: string) -> boolean,
    increment:   (self: SessionHandle, key: string, amount: number?) -> number,
    decrement:   (self: SessionHandle, key: string, amount: number?) -> number,
    reset:       (self: SessionHandle) -> (),
    derive:      (self: SessionHandle, key: string, fn: () -> any) -> (),
    link:        (self: SessionHandle, other: SessionHandle, keyA: string, keyB: string) -> (),
    persist:     (self: SessionHandle, key: string, datastore: any) -> (),
    history:     (self: SessionHandle, key: string, n: number?) -> { any },
    onChange:    (self: SessionHandle, key: string, cb: (any, any) -> ()) -> () -> (),
    onAnyChange: (self: SessionHandle, cb: (string, any, any) -> ()) -> () -> (),
    onBatch:     (self: SessionHandle, keys: { string }, cb: () -> ()) -> () -> (),
    snapshot:    (self: SessionHandle) -> { [string]: any },
    destroy:     (self: SessionHandle) -> (),
}
```

All types exported from `Mitt/Types.lua` and re-exported by the main module.

---

## Changelog

### v2.0.0 -- May 2026

**Breaking changes:** None. All v1 code runs without modification.

**Drivers**
- Added `driver` field to `ActionConfig` -- `"uis"` (default), `"ias"`, `"cas"`
- IAS driver creates real `InputAction`, `InputContext`, `InputBinding` instances; tears them down on `:destroy()`
- IAS driver exposes full `InputActionType` support -- `Bool`, `Direction1D`, `Direction2D`, `Direction3D`, `ViewportPosition`
- IAS driver supports `BindingConfig` objects with analog thresholds, response curves, axis scale, modifier keys, composite directions, clamp magnitude, pointer index, UIButton hookup
- IAS driver: `priority` and `sink` wire to native `InputContext.Priority` and `InputContext.Sink`
- IAS shared contexts -- multiple actions can share one native `InputContext` via `contextName`
- IAS lazy instantiation -- instances deferred until context is first pushed
- CAS driver adds `casPriority`, `processSink`, `mobile` callback fields

**Action Modes**
- Added `"hold"` -- fires `triggered` after `holdTime` seconds continuous hold
- Added `"doubletap"` -- two presses within `window`, no sequence config needed
- Added `"charge"` -- fires `charged` signal each tick with `0-1` progress, `released` carries final level
- Added `"mash"` -- fires `triggered` with `count` when press threshold met within window
- Added `"longpress"` -- mobile-first, fires after hold, cancels on early release
- Added `"gesture"` -- swipe detection on touch/mouse
- Added `"sequence"` -- alias for `"combo"` with `stepFired` signal

**New Signals**
- `charged` -- normalized `0-1` charge progress each Heartbeat tick
- `stateChanged` -- any value change, carries typed state (`boolean`, `number`, `Vector2`, `Vector3`)
- `stepFired` -- fires on each valid combo/sequence step before completion
- `canceled` -- combo, sequence, or charge broken before completion
- `conflicted` -- binding claimed by higher-priority action, carries winning handle
- `bindingsChanged` -- IAS binding added/removed at runtime
- `enabledChanged` -- action enabled state changed, carries new boolean
- `contextChanged` -- action's context pushed or popped

**New Handle Methods**
- `:getCharge()` -- current charge progress `0-1`
- `:getState()` -- current IAS state value
- `:getBindings()` -- live `InputBinding` instances (IAS)
- `:getPriority()` / `:setPriority(n)`
- `:getContext()` / `:transferContext(name)`
- `:history(n?)` -- last n input events
- `:mute()` / `:unmute()` -- suppress signals without disabling registration
- `:fire(state?)` -- programmatic trigger through full pipeline
- `:simulate(phase)` -- synthetic InputEvent respecting context and combos
- `:lockBinding()` -- prevent rebind via `rebindAll` or `import`
- `:clone(name, overrides?)` -- duplicate action with optional config diff

**Context System**
- `Mitt.context.push` now accepts inline `{ priority, sink }` options
- `Mitt.context.pushGroup(names)` -- atomic multi-push
- `Mitt.context.guard(name, predicate)` -- conditional context activation
- `Mitt.context.onPush(name, cb)` / `Mitt.context.onPop(name, cb)` -- lifecycle hooks
- `Mitt.context.snapshot()` / `Mitt.context.restore(snap)` -- stack state save/restore
- Exclusive contexts -- `exclusive = true` pops all others before pushing
- `Mitt.context.getActions(name)` -- returns handles registered to that context
- `Mitt.context.actionsChanged` signal (IAS driver)

**Sessions**
- `:derive(key, fn)` -- computed value auto-updating on dependency changes
- `:link(other, keyA, keyB)` -- bidirectional key sync between sessions
- `:persist(key, datastore)` -- auto-save key on change
- `:history(key, n?)` -- last n values for a key
- `:onBatch(keys, cb)` -- single callback after all listed keys change in same frame
- Session schema -- typed definitions with runtime type enforcement

**Platform**
- `Mitt.platform` namespace -- `current`, `onSwitch`, `changed` signal
- Per-binding `platforms` filter -- `{ "keyboard" | "gamepad" | "touch" }`
- `preferredInput` integration -- auto-promotes correct bindings on device switch
- Gyro/accelerometer action type -- `"gyro"` \| `"accel"`

**Mobile Touch Layer**
- `Mitt.touch.layout(config)` -- declare positions, Mitt creates and manages `ImageButton` instances in a dedicated `ScreenGui`
- `Mitt.touch.bind(action, button)` -- manually wire existing button
- `Mitt.touch.register(actionName, button)` -- self-registration by action name
- `Mitt.touch.theme(config)` -- idle/pressed colors, corner radius, icon tint, label font/size
- Context-aware visibility -- buttons auto-show/hide with action context
- Labels auto-update on rebind
- `draggable = true` -- player-repositionable buttons
- `Mitt.touch.exportLayout()` / `importLayout(data)` -- serializable positions
- `Mitt.touch.setIcon`, `getButton`, `show`, `hide`, `reset`

**Icon Library**
- `Mitt.Icons` -- 50+ named asset ID tokens across combat, movement, interaction, UI, weapons, vehicle, and ability slots
- `Mitt.Icons.Custom(assetId)` -- wrap any asset ID into the pipeline

**Async Operators**
- `Mitt.gate(action, predicate)` -- filtered signal wrapper
- `Mitt.debounce(action, seconds)` -- minimum re-fire gap
- `Mitt.throttle(action, seconds)` -- maximum fire rate
- `Mitt.map(action, fn)` -- InputEvent transform before subscribers
- `Mitt.after(action, n)` -- resolves on nth fire only
- `Mitt.any(signals)` -- resolves with all signals firing in the same frame
- `Mitt.repeat(action, interval, max?)` -- programmatic repeat loop

**Rebinding & Profiles**
- `Mitt.exportProfile(name)` / `importProfile(name)` -- named binding profiles
- `Mitt.diffBindings(profileA, profileB)` -- diff between two profiles
- `Mitt.resetToDefaults()` -- restore all actions to definition-time bindings
- `Mitt.getConflicts()` -- all actions sharing a binding grouped by context

**Debug & Tooling**
- `Mitt.record()` / `Mitt.stopRecord()` / `Mitt.replay(recording)` -- deterministic input recording
- `Mitt.assert(action, phase, timeout?)` -- test helper Promise
- `Mitt.audit()` -- report of unused, unbound, and conflicting actions
- `Mitt.profile()` -- signal dispatch latency per action
- Enhanced `Mitt.visualizer()` -- now shows context stack, session state, and binding conflicts
- Action tags -- `tags` field on config, `Mitt.getByTag(tag)`

---

### v1.0.0 -- May 2026

Initial release.

- Unified action registry via `Mitt.define`
- UIS backend with auto-inferred `button` / `axis` types
- Context stack with push/pop/peek/clear
- `button`, `axis`, `combo`, `shortcut` modes
- `pressed`, `released`, `held`, `moved`, `triggered` signals
- Signal `:connect` / `:once` / Promise chain
- `holdFor`, `isHeld`, `heldDuration`, `:next`
- Repeat mode via `repeatInterval`
- Deadzone filtering
- Sessions -- `createSession`, `getSession`, `modifySession`, `removeSession`
- SessionHandle -- `get`, `set`, `patch`, `toggle`, `increment`, `decrement`, `reset`, `onChange`, `onAnyChange`, `snapshot`, `destroy`
- Raw input layer -- `Mitt.input.on`, `Mitt.input.held`
- `Mitt.race`, `Mitt.sequence`, `Mitt.timeout`, `Mitt.buffer`, `Mitt.waitFor`
- `Mitt.rebindAll`, `Mitt.export`, `Mitt.import`
- `Mitt.visualizer()`
- Full Luau strict-typed exports

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

*Last Updated: May 2026*
---