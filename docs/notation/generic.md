# Types

Generic signed integer
- int{n} - n-bits signed integer
- int - signed integer with undefined bit count

Non-zero signed integer
- nint{n}
- nint

Unsigned integer
- uint{n}
- uint

Positive unsigned integer
- pint{n}
- pint

Any number
- `number`

Nil value is always explicit.

Variant types: `x | y` means either `x` or `y` can be there.

Lua table as hashtable: `table(keyname: KeyType, valuename: ValueType)`, keyname and valuename are optional and for readers only.

Lua table as array: `array(valuename: ValueType)`, valuename is optional.

Other Lua and GMod types identified by their name (`string`, `Entity`, `Player`, etc.).

Metatable of SomeType: `metatable(SomeType)`.

Instance of type can be used as type itself (like `table(Entity, true)`, `nint | 0 | 1.2 | "sometext"`).

# Functions
Non-member function: `fn .FunctionName(arg1: T1, arg2: T2, {...}) -> result1: TR1, result2: TR2`
Member function: `fn :FunctionName(arg: T) -> result: TResult`.

Varardic argument: `fn .func(arg: T, va: ...T) -> result: ...T2`

# Values
- `var .Name: T` - can be assigned to
- `readonly .Name: T` - should not be assigned to (by user code)
- `const .Name: T` - can be assumed to be a constant, should not be assigned to (after instantiation)

# GMod hooks
- `hook .HookName(args: ...TArgs) -> result: TResult|nil`
Should be in namespaces, not in structs/interfaces.

In `hook.Add`/`hook.Run` full item name is used.

# Type aliases
`type .Alias = AliasedType`

# Structs and interfaces

`struct .StructName { {...items} }` - Represent metatables that can be made into instances.
`interface .InterfaceName { {...items} }` - Represents parts of metatables.

Type restrictions:
- `metatable(.StructName) | metatable(.InterfaceName)` - table (metatable) that contains `...items`
- `.InterfaceName` - table that contains `...items` and maybe other fields.
- `.StructName` - table that contains `...items` and no other items. (Not considering fields set by external code.)


Items (`{...items}`) can be functions, values, interface requirements and other structs and interfaces.

Interface requirement: `require .InterfaceName` - containing interface or struct should contain items from given interface. 

# Namespaces
