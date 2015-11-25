# Copyright (c) 2015, Diego Souza
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# 
# 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

defmodule ExMagick do
  use ExMagick.Bang
  
  @docmodule """
  NIF bindings to GraphicsImage library.
  """

  @on_load {:load, 0}
  def load do
    sofile = Path.join([:code.priv_dir(:exmagick), "lib", "libexmagick"])
    :erlang.load_nif(sofile, 0)
  end

  @doc """
  Change image attributes. Currently the following attributes are
  available:

  * adjoin [default: true]: unset to produce single image for each
  frame;
  """

  @defbang {:attr, 3}
  def attr(img, k, v) when is_atom(k) do
    case k do
      :adjoin when is_boolean(v) -> set_attr(img, k, v)
      _                          -> {:error, "unknown attr #{k}/#{v}"}
    end
  end

  @doc """ 

  Query image attrs. In addition to the flags defined in `flag/3` the
  following is avaialble:

  * magick: Image encoding format (e.g. "GIF");
  """
  @defbang {:attr, 2}
  def attr(img, k), do: get_attr(img, k)

  @doc """
  Query an 
  """

  @doc """
  Creates a new image structure with default values. You may tune
  image params using the `flag` function.
  """
  @defbang {:image, 0}
  def image, do: fail

  @doc """
  Loads an image from a file.
  """
  @defbang {:image_load, 2}
  def image_load(_img, _path), do: fail

  @doc """
  Saves an image to one or multiple files. If the flag adjoin is false
  multiple files will be created and the filename is expected to have
  a printf-formatting sytle (ex.: foo%0d.png).
  """
  @defbang {:image_dump, 2}
  def image_dump(_img, _path), do: fail

  defp set_attr(_img, _key, _val), do: fail
  defp get_attr(_img, _key), do: fail
  
  defp fail, do: {:error, "native function"}
end
