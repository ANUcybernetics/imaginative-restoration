defmodule ImaginativeRestorationWeb.ErrorJSONTest do
  use ImaginativeRestorationWeb.ConnCase, async: true

  test "renders 404" do
    assert ImaginativeRestorationWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert ImaginativeRestorationWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
