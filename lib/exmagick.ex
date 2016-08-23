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
  @moduledoc """
  NIF bindings to the GraphicsMagick API.

  ## Examples

  *Transform a PNG image to JPEG*
  ```
  ExMagick.init!()
  |> ExMagick.image_load!(Path.join(__DIR__, "../test/images/elixir.png"))
  |> ExMagick.image_dump!("/tmp/elixir.jpg")
  ```

  *Query a file type*
  ```
  ExMagick.init!()
  |> ExMagick.image_load!(Path.join(__DIR__, "../test/images/elixir.png"))
  |> ExMagick.attr!(:magick)
  ```

  *Generate a thumbnail from an image*
  ```
  ExMagick.init!()
  |> ExMagick.image_load!(Path.join(__DIR__, "../test/images/elixir.png"))
  |> ExMagick.thumb!(64, 64)
  |> ExMagick.image_dump!("/tmp/elixir-thumbnail.jpg")
  ```

  *Generate a thumbnail from an image without breaking errors*
  ```
  with {:ok, handler} <- ExMagick.init(),
       img_path = Path.join(__DIR__, "../test/images/elixir.png"),
       {:ok, _} <- ExMagick.image_load(handler, img_path),
       {:ok, _} <- ExMagick.thumb(handler, 128, 64),
       thumb_path = "/tmp/elixir-thumbnail.png",
       {:ok, _} <- ExMagick.image_dump(handler, thumb_path),
    do: {:ok, thumb_path}
  ```

  * Converting a multi-page PDF to individual PNG images with 300dpi
  ```
  ExMagick.init!
  |> ExMagick.attr!(:density, "300") # density should be set before loading the image
  |> ExMagick.image_load!(Path.joint(__DIR__, "../test/images/elixir.pdf"))
  |> ExMagick.attr!(:adjoin, false)
  |> ExMagick.image_dump!("/tmp/splitted-page-%0d.png")
  ```

  """

  @typedoc """
  A handle used by the GraphicsMagick API

  It's internal structure should never be assumed, instead, it should be used
  with this module's functions
  """
  @opaque image :: <<>>

  @on_load {:load, 0}
  @spec load() :: no_return
  @doc false
  def load do
    sofile = Path.join([:code.priv_dir(:exmagick), "lib", "libexmagick"])
    :erlang.load_nif(sofile, 0)
  end

  @spec attr!(image, atom, term) :: image
  def attr!(handle, attribute, value) do
    {:ok, handle} = attr(handle, attribute, value)
    handle
  end

  @spec attr(image, atom, term) :: {:ok, image} | {:error, reason :: term}
  @doc """
  Changes image `attribute`s.

  Currently the following `attribute`s are available:
  * `:adjoin` (defaults to `true`) - set to `false` to produce different images
  for each frame;
  """
  def attr(handle, attribute, value) when is_atom(attribute) do
    case attribute do
      :adjoin when is_boolean(value) ->
        set_attr(handle, attribute, value)
      _ ->
        {:error, "unknown attribute #{attribute}"}
    end
  end

  @spec attr!(image, atom) :: image
  def attr!(handle, attribute) do
    {:ok, handle} = attr(handle, attribute)
    handle
  end

  @spec attr(image, atom) :: {:ok, attr_value :: term} | {:error, reason :: term}
  @doc """
  Queries `attribute` on image.

  In addition to the attributess defined in `attr/3`, the following are
  available:
  * `:magick` - Image encoding format (e.g. "GIF");
  """
  def attr(handle, attribute), do: get_attr(handle, attribute)

  @spec size!(image) :: %{height: pos_integer, width: pos_integer}
  def size!(handle) do
    {:ok, image_size} = size(handle)
    image_size
  end

  @spec size(image) :: {:ok, %{height: pos_integer, width: pos_integer}}
  @doc """
  Queries the image size
  """
  def size(handle) do
    with \
      {:ok, width}  <- attr(handle, :columns),
      {:ok, height} <- attr(handle, :rows)
    do
      {:ok, %{width: width, height: height}}
    end
  end

  @spec size!(image, pos_integer, pos_integer) :: image
  def size!(handle, width, height) do
    {:ok, handle} = size(handle, width, height)
    handle
  end

  @spec size(image, pos_integer, pos_integer) :: {:ok, image} | {:error, reason :: term}
  @doc """
  Resizes the image.
  """
  def size(_handle, _width, _height), do: fail

  @spec crop!(image, non_neg_integer, non_neg_integer, non_neg_integer, non_neg_integer) :: image
  def crop!(handle, x, y, width, height) do
    {:ok, handle} = crop(handle, x, y, width, height)
    handle
  end

  @spec crop(image, non_neg_integer, non_neg_integer, non_neg_integer, non_neg_integer) :: {:ok, image} | {:error, reason :: term}
  @doc """
  Crops the image.

  * x,y refer to starting point, where (0,0) is top left
  """
  def crop(_handle, _x, _y, _width, _height), do: fail


  @spec thumb!(image, pos_integer, pos_integer) :: image
  def thumb!(handle, width, height) do
    {:ok, handle} = thumb(handle, width, height)
    handle
  end

  @spec thumb(image, pos_integer, pos_integer) :: {:ok, image} | {:error, reason :: term}
  @doc """
  Generates a thumbnail for image.

  _Note that this method resizes the image as quickly as possible, with more
  concern for speed than resulting image quality._
  """
  def thumb(_handle, _width, _height), do: fail

  @doc false
  def image! do
    {:ok, handle} = image()
    handle
  end

  @doc false
  def image do
    IO.puts :stderr, "warning: image is deprecated in favor of init." <> Exception.format_stacktrace
    init
  end

  @spec init!() :: image
  def init! do
    {:ok, handle} = init()
    handle
  end

  @spec init() :: {:ok, image} | {:error, reason :: term}
  @doc """
  Creates a new image handle with default values.

  Image attributes may be tuned by using the `attr/2` function.
  """
  def init, do: fail

  @spec image_load!(image, Path.t) :: image
  def image_load!(handle, path) do
    {:ok, handle} = image_load(handle, path)
    handle
  end

  @spec image_load(image, Path.t) :: {:ok, image} | {:error, reason :: term}
  @doc """
  Loads into the handler an image from a file.
  """
  def image_load(_handle, _path), do: fail

  @spec image_dump!(image, Path.t) :: image
  def image_dump!(handle, path) do
    {:ok, handle} = image_dump(handle, path)
    handle
  end

  @spec image_dump(image, Path.t) :: {:ok, image} | {:error, reason :: term}
  @doc """
  Saves an image to one or multiple files.

  If the attr `:adjoin` is `false`, multiple files will be created and the
  filename is expected to have a printf-formatting sytle (ex.: `foo%0d.png`).
  """
  def image_dump(_handle, _path), do: fail

  @spec set_attr(image, atom, term) :: {:ok, image} | {:error, reason :: term}
  defp set_attr(_handle, _attribute, _value), do: fail

  @spec get_attr(image, atom) :: {:ok, attr_value :: term} | {:error, reason :: term}
  defp get_attr(_handle, _attribute), do: fail

  defp fail, do: {:error, "native function"}
end
