defmodule ExMagickTest do
  use ExUnit.Case, async: true

  setup do
    tmpdir =
      Enum.reduce_while(0..100, nil, fn _, _ ->
        rand = :erlang.unique_integer([:positive])
        path = Path.join(System.tmp_dir!(), "#{rand}")

        case File.mkdir(path) do
          :ok -> {:halt, path}
          _ -> {:cont, nil}
        end
      end)

    on_exit(fn ->
      File.rm_rf!(tmpdir)
    end)

    {:ok, [tmpdir: tmpdir]}
  end

  setup_all do
    {:ok, [images: Path.expand("images/", __DIR__)]}
  end

  test "image_load(:png) and image_save(:jpg)", context do
    src = Path.join(context[:images], "elixir.png")
    dst = Path.join(context[:tmpdir], "elixir.jpg")

    ExMagick.init!()
    |> ExMagick.image_load!(src)
    |> ExMagick.image_dump!(dst)

    assert File.exists?(dst)
  end

  test "magick attr", context do
    png = Path.join(context[:images], "elixir.png")
    mgk = Enum.random(["PDF", "GIF", "JPEG", "PNG"])

    exm =
      ExMagick.init!()
      |> ExMagick.image_load!(png)

    ExMagick.attr!(exm, :magick, mgk)
    assert mgk == ExMagick.attr!(exm, :magick)
  end

  test "load from blob", context do
    png = File.read!(Path.join(context[:images], "elixir.png"))

    assert "PNG" ==
             ExMagick.init!()
             |> ExMagick.image_load!({:blob, png})
             |> ExMagick.attr!(:magick)
  end

  test "load(:png) and write(:blob, :jpg)", context do
    png = Path.join(context[:images], "elixir.png")

    jpg =
      ExMagick.init!()
      |> ExMagick.image_load!(png)
      |> ExMagick.attr!(:magick, "JPEG")
      |> ExMagick.image_dump!()

    assert "JPEG" ==
             ExMagick.init!()
             |> ExMagick.image_load!({:blob, jpg})
             |> ExMagick.attr!(:magick)
  end

  test "get image size", %{images: images} do
    src = Path.join(images, "elixir.png")

    size =
      ExMagick.init!()
      |> ExMagick.image_load!(src)
      |> ExMagick.size!()

    assert %{width: w, height: h} = size
    assert 227 == w
    assert 95 == h
  end

  test "resizes an image", %{images: images} do
    src = Path.join(images, "elixir.png")

    image =
      ExMagick.init!()
      |> ExMagick.image_load!(src)

    assert %{width: 227, height: 95} == ExMagick.size!(image)

    new_size =
      image
      |> ExMagick.size!(100, 42)
      |> ExMagick.size!()

    assert %{width: 100, height: 42} == new_size
  end

  test "thumbnails an image", %{images: images} do
    src = Path.join(images, "elixir.png")

    image =
      ExMagick.init!()
      |> ExMagick.image_load!(src)

    assert %{width: 227, height: 95} == ExMagick.size!(image)

    new_size =
      image
      |> ExMagick.thumb!(42, 42)
      |> ExMagick.size!()

    assert %{width: 42, height: 42} == new_size
  end

  test "resizes and saves image", %{images: images, tmpdir: tmpdir} do
    src = Path.join(images, "elixir.png")
    dst = Path.join(tmpdir, "resized.png")

    size =
      ExMagick.init!()
      |> ExMagick.image_load!(src)
      |> ExMagick.size!(100, 42)
      |> ExMagick.image_dump!(dst)
      |> ExMagick.image_load!(dst)
      |> ExMagick.size!()

    assert %{width: 100, height: 42} == size
  end

  test "crops image", %{images: images, tmpdir: tmpdir} do
    src = Path.join(images, "elixir.png")
    dst = Path.join(tmpdir, "cropped.png")

    size =
      ExMagick.init!()
      |> ExMagick.image_load!(src)
      |> ExMagick.crop!(0, 0, 100, 10)
      |> ExMagick.image_dump!(dst)
      |> ExMagick.image_load!(dst)
      |> ExMagick.size!()

    assert %{width: 100, height: 10} == size
  end

  test "load PDF with density", %{images: images} do
    src = Path.join(images, "elixir.pdf")

    image =
      ExMagick.init!()
      |> ExMagick.image_load!(src)

    assert %{width: 227, height: 95} == ExMagick.size!(image)

    size_with_density =
      ExMagick.init!()
      |> ExMagick.attr!(:density, "300")
      |> ExMagick.image_load!(src)
      |> ExMagick.size!()

    assert %{width: 946, height: 396} == size_with_density
  end

  test "adjoin attribute" do
    value = ExMagick.init!() |> ExMagick.attr(:adjoin)

    assert {:ok, true} == value
  end

  test "magick attribute", context do
    for {type, path} <- [
          {"PDF", Path.join(context[:images], "elixir.pdf")},
          {"PNG", Path.join(context[:images], "elixir.png")}
        ] do
      value =
        ExMagick.init!()
        |> ExMagick.image_load!(path)
        |> ExMagick.attr!(:magick)

      assert type == value
    end
  end

  test "image_load(:pdf) and image_save(:jpg)", context do
    src = Path.join(context[:images], "elixir.pdf")
    dst = Path.join(context[:tmpdir], "elixir.jpg")

    ExMagick.init!()
    |> ExMagick.image_load!(src)
    |> ExMagick.image_dump!(dst)

    assert File.exists?(dst)
  end

  test "image_load(:pdf) and image_save([:jpg])", context do
    src = Path.join(context[:images], "elixir.pdf")
    dst = Path.join(context[:tmpdir], "elixir%0d.jpg")

    ExMagick.init!()
    |> ExMagick.image_load!(src)
    |> ExMagick.attr!(:adjoin, false)
    |> ExMagick.image_dump!(dst)

    refute File.exists?(dst)
    assert 10 == length(File.ls!(context[:tmpdir]))
  end

  test "num_pages counts pages, multi page pdf", context do
    src = Path.join(context[:images], "elixir.pdf")

    num_pages =
      ExMagick.init!()
      |> ExMagick.image_load!(src)
      |> ExMagick.num_pages!()

    assert 10 == num_pages
  end

  test "num_pages counts pages, png", context do
    src = Path.join(context[:images], "elixir.png")

    num_pages =
      ExMagick.init!()
      |> ExMagick.image_load!(src)
      |> ExMagick.num_pages!()

    assert 1 == num_pages
  end
end
