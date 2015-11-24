defmodule ExMagick.Bang do

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
