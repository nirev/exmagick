defmodule ExMagickTest do
  use ExUnit.Case, async: true

  setup do
    tmpdir = Enum.reduce_while(0..100, nil, fn _, _ ->
      rand = :erlang.unique_integer([:positive])
      path = Path.join System.tmp_dir!, "#{rand}"
      case (File.mkdir path) do
        :ok -> {:halt, path}
        _   -> {:cont, nil}
      end
    end)
    on_exit fn ->
      File.rm_rf! tmpdir
    end
    {:ok, [tmpdir: tmpdir]}
  end

  setup_all do
    {:ok, [images: Path.expand("images/", __DIR__)]}
  end

  test "image_load(:png) and image_save(:jpg)", context do
    src = Path.join context[:images], "elixir.png"
    dst = Path.join context[:tmpdir], "elixir.jpg"
    ExMagick.image!
    |> ExMagick.image_load!(src)
    |> ExMagick.image_dump!(dst)
    assert (File.exists? dst)
  end

  test "get image size", %{images: images} do
    src = Path.join images, "elixir.png"
    size = ExMagick.image!
    |> ExMagick.image_load!(src)
    |> ExMagick.size!

    assert %{width: w, height: h} = size
    assert 227 == w
    assert  95 == h
  end

  test "resizes an image", %{images: images} do
    src = Path.join images, "elixir.png"

    image = ExMagick.image!
    |> ExMagick.image_load!(src)

    assert %{width: 227, height: 95} == ExMagick.size!(image)

    new_size = image
    |> ExMagick.size!(100, 42)
    |> ExMagick.size!

    assert %{width: 100, height: 42} == new_size
  end

  test "resizes and saves image", %{images: images, tmpdir: tmpdir} do
    src = Path.join images, "elixir.png"
    dst = Path.join tmpdir, "resized.png"

    size = ExMagick.image!
    |> ExMagick.image_load!(src)
    |> ExMagick.size!(100, 42)
    |> ExMagick.image_dump!(dst)
    |> ExMagick.image_load!(dst)
    |> ExMagick.size!

    assert %{width: 100, height: 42} == size
  end

  test "adjoin attribute" do
    value = ExMagick.image! |> ExMagick.attr(:adjoin)
    assert {:ok, true} == value
  end

  test "magick attribute", context do
    for {type, path} <- [ {"PDF", (Path.join context[:images], "elixir.pdf")},
                          {"PNG", (Path.join context[:images], "elixir.png")}
                        ] do
      value = ExMagick.image!
      |> ExMagick.image_load!(path)
      |> ExMagick.attr!(:magick)
      assert type == value
    end
  end

  test "image_load(:pdf) and image_save(:jpg)", context do
    src = Path.join context[:images], "elixir.pdf"
    dst = Path.join context[:tmpdir], "elixir.jpg"
    ExMagick.image!
    |> ExMagick.image_load!(src)
    |> ExMagick.image_dump!(dst)
    assert (File.exists? dst)
  end

  test "image_load(:pdf) and image_save([:jpg])", context do
    src = Path.join context[:images], "elixir.pdf"
    dst = Path.join context[:tmpdir], "elixir%0d.jpg"
    ExMagick.image!
    |> ExMagick.image_load!(src)
    |> ExMagick.attr!(:adjoin, false)
    |> ExMagick.image_dump!(dst)
    refute (File.exists? dst)
    assert 10 == length(File.ls! context[:tmpdir])
  end

end
