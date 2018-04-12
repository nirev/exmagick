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
  NIF bindings to the GraphicsMagick API with optional support for
  dirty scheduling.

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
  An opaque handle used by the GraphicsMagick API
  """
  @opaque handle :: binary

  @type exm_error :: {:error, String.t()}

  @on_load {:load, 0}

  @doc false
  @spec load :: :ok | {:error, {atom, charlist}}
  def load do
    [:code.priv_dir(:exmagick), "lib/libexmagick"]
    |> Path.join()
    |> String.to_charlist()
    |> :erlang.load_nif(0)
  end

  @doc """
  Refer to `attr/3`
  """
  @spec attr!(handle, :atom, String.t() | boolean) :: handle
  def attr!(handle, attribute, value) do
    {:ok, handle} = attr(handle, attribute, value)
    handle
  end

  @doc """
  Changes image `attribute`s.

  Currently the following `attribute`s are available:
  * `:adjoin` (defaults to `true`) - set to `false` to produce different images
  for each frame;
  * `:magick` - the image type [ex.: PNG]
  * `:density` - horizontal and vertical resolution in pixels of this image; [default: 72]
  """
  @spec attr(handle, :atom, String.t() | boolean) :: {:ok, handle} | exm_error
  def attr(handle, attribute, value) when is_atom(attribute) do
    case attribute do
      :adjoin when is_boolean(value) ->
        set_attr(handle, attribute, value)

      :density when is_binary(value) ->
        set_attr(handle, attribute, value)

      :magick when is_binary(value) ->
        set_attr(handle, attribute, value)

      _ ->
        {:error, "unknown attribute #{attribute}"}
    end
  end

  @doc """
  Refer to `attr/2`
  """
  @spec attr!(handle, atom) :: String.t() | boolean | non_neg_integer
  def attr!(handle, attribute) do
    {:ok, handle} = attr(handle, attribute)
    handle
  end

  @doc """
  Queries `attribute` on image. Refer to `attr/3` for more information.

  In addition to `attr/3` the following attributes are defined:

  * `:rows` The horizontal size in pixels of the image
  * `:columns` The vertical size in pixels of the image
  """
  @spec attr(handle, atom) :: {:ok, String.t() | boolean | non_neg_integer} | exm_error
  def attr(handle, attribute), do: get_attr(handle, attribute)

  @doc """
  Computes the number of pages of an image.
  """
  @spec num_pages(handle) :: {:ok, non_neg_integer} | exm_error
  def num_pages(_handle), do: fail()

  @doc """
  Refer to `num_pages/1`
  """
  @spec num_pages!(handle) :: non_neg_integer | exm_error
  def num_pages!(handle) do
    {:ok, pages} = num_pages(handle)
    pages
  end

  @doc """
  Refer to `size/1`.
  """
  @spec size!(handle) :: %{width: non_neg_integer, height: non_neg_integer}
  def size!(handle) do
    {:ok, image_size} = size(handle)
    image_size
  end

  @doc """
  Queries the image size
  """
  @spec size(handle) :: {:ok, %{width: non_neg_integer, height: non_neg_integer}} | exm_error
  def size(handle) do
    with {:ok, width} <- attr(handle, :columns),
         {:ok, height} <- attr(handle, :rows) do
      {:ok, %{width: width, height: height}}
    end
  end

  @doc """
  Refer to `size/3`
  """
  @spec size!(handle, non_neg_integer, non_neg_integer) :: handle
  def size!(handle, width, height) do
    {:ok, handle} = size(handle, width, height)
    handle
  end

  @doc """
  Resizes the image.
  """
  @spec size(handle, non_neg_integer, non_neg_integer) :: {:ok, handle} | exm_error
  def size(_handle, _width, _height), do: fail()

  @doc """
  Refer to `crop/5`.
  """
  @spec crop!(handle, non_neg_integer, non_neg_integer, non_neg_integer, non_neg_integer) ::
          handle
  def crop!(handle, x, y, width, height) do
    {:ok, handle} = crop(handle, x, y, width, height)
    handle
  end

  @doc """
  Crops the image.

  * `x`, `y` refer to starting point, where (0, 0) is top left
  """
  @spec crop(handle, non_neg_integer, non_neg_integer, non_neg_integer, non_neg_integer) ::
          {:ok, handle} | exm_error
  def crop(_handle, _x, _y, _width, _height), do: fail()

  @spec thumb!(handle, non_neg_integer, non_neg_integer) :: handle
  def thumb!(handle, width, height) do
    {:ok, handle} = thumb(handle, width, height)
    handle
  end

  @doc """
  Generates a thumbnail for image.

  _Note that this method resizes the image as quickly as possible, with more
  concern for speed than resulting image quality._
  """
  @spec thumb(handle, non_neg_integer, non_neg_integer) :: {:ok, handle} | exm_error
  def thumb(_handle, _width, _height), do: fail()

  @doc false
  def image! do
    {:ok, handle} = image()
    handle
  end

  @doc false
  def image do
    IO.puts(
      :stderr,
      "warning: image is deprecated in favor of init." <> Exception.format_stacktrace()
    )

    init()
  end

  @doc """
  Refer to `init/0`
  """
  @spec init! :: handle
  def init! do
    {:ok, handle} = init()
    handle
  end

  @doc """
  Creates a new image handle with default values.

  Image attributes may be tuned by using the `attr/3` function.
  """
  def init, do: fail()

  @doc """
  Refer to `image_load!/2`
  """
  @spec image_load!(handle, Path.t() | {:blob, binary}) :: handle
  def image_load!(handle, path_or_blob) do
    {:ok, handle} = image_load(handle, path_or_blob)
    handle
  end

  @doc """
  Loads an image into the handler. You may provide a file path or a
  tuple `{:blob, ...}` which the second argument is the blob to load.
  """
  @spec image_load(handle, Path.t() | {:blob, binary}) :: {:ok, handle} | exm_error
  def image_load(handle, {:blob, blob}), do: image_load_blob(handle, blob)
  def image_load(handle, path), do: image_load_file(handle, path)

  @doc """
  Refer to `image_dump/2`
  """
  @spec image_dump!(handle, Path.t()) :: handle
  def image_dump!(handle, path) do
    {:ok, handle} = image_dump(handle, path)
    handle
  end

  @doc """
  Saves an image to one or multiple files.

  If the attr `:adjoin` is `false`, multiple files will be created and the
  filename is expected to have a printf-formatting sytle (ex.: `foo%0d.png`).
  """
  @spec image_dump(handle, Path.t()) :: {:ok, handle} | exm_error
  def image_dump(handle, path), do: image_dump_file(handle, path)

  @doc """
  Returns the image as a binary. You can change the type of this image
  using the `:magick` attribute.
  """
  @spec image_dump(handle) :: {:ok, binary} | exm_error
  def image_dump(handle), do: image_dump_blob(handle)

  @doc """
  Refer to `image_dump/1`
  """
  @spec image_dump!(handle) :: binary
  def image_dump!(handle) do
    {:ok, blob} = image_dump(handle)
    blob
  end

  @spec image_load_file(handle, Path.t()) :: {:ok, handle} | exm_error
  defp image_load_file(_handle, _path), do: fail()

  @spec image_load_blob(handle, binary) :: {:ok, handle} | exm_error
  defp image_load_blob(_handle, _blob), do: fail()

  @spec image_dump_file(handle, Path.t()) :: {:ok, handle} | exm_error
  defp image_dump_file(_handle, _path), do: fail()

  @spec image_dump_blob(handle) :: {:ok, binary} | exm_error
  defp image_dump_blob(_handle), do: fail()

  @spec set_attr(handle, atom, String.t() | boolean) :: {:ok, handle} | exm_error
  defp set_attr(_handle, _attribute, _value), do: fail()

  @spec get_attr(handle, atom) :: {:ok, String.t() | boolean | non_neg_integer} | exm_error
  defp get_attr(_handle, _attribute), do: fail()

  # XXX: this is to fool dialyzer
  defp fail, do: ExMagick.Hidden.fail("native function error")
end
