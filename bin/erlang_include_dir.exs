#!/usr/bin/env elixir

[:code.root_dir(), ["erts-", :erlang.system_info(:version)], "include"]
|> Path.join()
|> IO.puts()
