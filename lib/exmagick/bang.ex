defmodule ExMagick.Bang do

  @docmodule """
  Defines an  @defbang functions  that creates the  bang version  of a
  function. The original function is expected to return `{:ok, value}`
  on success. Example:

  iex> defmodule Foobar do
  ...>   use ExMagick.Bang
  ...>
  ...>   @defbang {foo, 0}
  ...>   def foo, do: {:ok, "o.o"}
  ...> end

  `@defbang` can be used multiple times and can be anywhere in the
  code.
  """
  
  defmacro __using__(_) do
    quote do
      Module.register_attribute __MODULE__, :defbang, accumulate: true, persist: false
      @before_compile ExMagick.Bang
    end
  end

  defmacro __before_compile__(env) do
    for {func, arity} <- Module.get_attribute(env.module, :defbang) do
      unless (Module.defines? env.module, {func, arity}, :def) or (Module.defines? env.module, {func, arity}, :defp) do
        raise "no function {#{func},#{arity}}"
      end
      args = for index <- Enum.drop 0..arity, 1 do
        Macro.var (String.to_atom "arg#{index}"), env.module
      end
      bang = String.to_atom "#{func}!"
      code = quote do
        def unquote(bang)() do
          {:ok, value} = apply(unquote(env.module), unquote(func), unquote(args))
          value
        end
      end
      Macro.postwalk(code, fn
        ({name, context, []}) when name == bang -> {name, context, args}
        (other)                                 -> other
      end)
    end
  end

end
