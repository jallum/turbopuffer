defmodule Turbopuffer.ResultTest do
  use ExUnit.Case

  alias Turbopuffer.Result

  describe "from_map/1" do
    test "converts map with flattened attributes" do
      map = %{
        "id" => "doc1",
        "dist" => 0.123,
        "name" => "test",
        "category" => "example",
        "vector" => [0.1, 0.2, 0.3]
      }

      result = Result.from_map(map)

      assert %Result{
               id: "doc1",
               dist: 0.123,
               attributes: %{"name" => "test", "category" => "example"},
               vector: [0.1, 0.2, 0.3]
             } = result
    end

    test "converts map with $dist field" do
      map = %{
        "id" => 1,
        "$dist" => 0.456,
        "category" => "example",
        "public" => 1
      }

      result = Result.from_map(map)

      assert %Result{
               id: 1,
               dist: 0.456,
               attributes: %{"category" => "example", "public" => 1},
               vector: nil
             } = result
    end

    test "handles missing optional fields" do
      map = %{"id" => "doc2"}

      result = Result.from_map(map)

      assert %Result{
               id: "doc2",
               dist: nil,
               attributes: nil,
               vector: nil
             } = result
    end
  end

  describe "from_maps/1" do
    test "converts list of maps" do
      maps = [
        %{"id" => "doc1", "dist" => 0.1},
        %{"id" => "doc2", "$dist" => 0.2},
        %{"id" => 3, "test" => true, "name" => "example"}
      ]

      results = Result.from_maps(maps)

      assert [
               %Result{id: "doc1", dist: 0.1, attributes: nil},
               %Result{id: "doc2", dist: 0.2, attributes: nil},
               %Result{id: 3, dist: nil, attributes: %{"test" => true, "name" => "example"}}
             ] = results
    end
  end
end
