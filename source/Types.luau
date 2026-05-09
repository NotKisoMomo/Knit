export type Phase = "pressed" | "released" | "changed"
export type ActionMode = "button" | "axis" | "combo" | "chord" | "shortcut"

export type InputBinding = Enum.KeyCode | Enum.UserInputType

export type ActionConfig = {
	bindings: { InputBinding },
	contexts: { string }?,
	mode: ActionMode?,
	sequence: { InputBinding }?,
	window: number?,
	deadzone: number?,
	repeatInterval: number?,
}

export type InputEventData = {
	binding: InputBinding,
	phase: Phase,
	position: Vector2?,
	delta: Vector2?,
	held: boolean,
	consumed: boolean,
}

export type Signal<T> = {
	connect: (self: Signal<T>, cb: (T) -> ()) -> () -> (),
	once: (self: Signal<T>) -> Promise<T>,
	fire: (self: Signal<T>, value: T) -> (),
	destroy: (self: Signal<T>) -> (),
}

export type Promise<T> = {
	andThen: (self: Promise<T>, cb: (T) -> ()) -> Promise<T>,
	catch: (self: Promise<T>, cb: (any) -> ()) -> Promise<T>,
	cancel: (self: Promise<T>) -> (),
	await: (self: Promise<T>) -> T,
}

export type ActionHandle = {
	pressed: Signal<InputEvent>,
	released: Signal<InputEvent>,
	held: Signal<InputEvent>,
	moved: Signal<InputEvent>,
	triggered: Signal<InputEvent>,

	isHeld: (self: ActionHandle) -> boolean,
	heldDuration: (self: ActionHandle) -> number,
	holdFor: (self: ActionHandle, seconds: number) -> Promise<InputEvent>,
	next: (self: ActionHandle) -> Promise<InputEvent>,
	log: (self: ActionHandle) -> (),
	rebind: (self: ActionHandle, bindings: { InputBinding }) -> (),
	enable: (self: ActionHandle) -> (),
	disable: (self: ActionHandle) -> (),
	destroy: (self: ActionHandle) -> (),
}

export type InputEvent = typeof(setmetatable({} :: InputEventData,{} :: { __index: { consume: (self: any) -> () } }))

export type SessionHandle = {
	get: (self: SessionHandle, key: string) -> any,
	set: (self: SessionHandle, key: string, value: any) -> (),
	patch: (self: SessionHandle, data: { [string]: any }) -> (),
	toggle: (self: SessionHandle, key: string) -> boolean,
	increment: (self: SessionHandle, key: string, amount: number?) -> number,
	decrement: (self: SessionHandle, key: string, amount: number?) -> number,
	reset: (self: SessionHandle) -> (),
	onChange: (self: SessionHandle, key: string, cb: (any, any) -> ()) -> () -> (),
	onAnyChange: (self: SessionHandle, cb: (key: string, value: any, previous: any) -> ()) -> () -> (),
	snapshot: (self: SessionHandle) -> { [string]: any },
	destroy: (self: SessionHandle) -> (),
}

return {}