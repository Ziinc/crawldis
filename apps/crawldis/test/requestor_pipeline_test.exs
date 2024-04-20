defmodule Crawldis.RequestorPipelineTest do
  @moduledoc false
  use Crawldis.CrawlCase
  alias Crawldis.RequestorPipeline
  alias Crawldis.Request
  alias Crawldis.CrawlJob

  describe "extract_data/1" do
    test "can select normal node" do
      body = """
      <html>
        <div>123 <span>testing</span></div>
        <div>345</div>
      </html>
      """

      for rule <- [
            "css: div span",
            "xpath: //div/span"
          ] do
        rules = %{"my_data" => %{"value" => rule}}

        assert %{
                 "my_data" => %{"value" => "testing"}
               } = run_extraction(body, rules)
      end
    end

    test "can select multiple nodes" do
      body = """
      <html>
        <div>123 <span>testing</span></div>
        <div>345 <span>tester</span></div>
      </html>
      """

      for rule <- ["css: div span", "xpath: //div/span"] do
        rules = %{"my_data" => %{"value" => [rule]}}

        assert %{
                 "my_data" => %{"value" => [_, _]}
               } = run_extraction(body, rules)
      end
    end

    test "can select node attributes" do
      body = """
      <html>
        <div>123 <span data-field="abc">testing</span></div>
      </html>
      """

      for rule <- [
            "css: div span::attr('data-field')",
            "xpath: //div/span/@data-field"
          ] do
        rules = %{
          "my_data" => %{"value" => rule}
        }

        assert %{
                 "my_data" => %{"value" => "abc"}
               } = run_extraction(body, rules)
      end
    end

    test "can select multiple node attributes" do
      body = """
      <html>
        <div>123 <span data-field="abc">testing</span></div>
        <div>123 <span data-field="def">testing</span></div>
      </html>
      """

      for rule <- [
            "css: div span::attr('data-field')",
            "xpath: //div/span/@data-field"
          ] do
        rules = %{
          "my_data" => %{"value" => [rule]}
        }

        assert %{
                 "my_data" => %{"value" => [_, _] = values}
               } = run_extraction(body, rules)

        assert "abc" in values and "def" in values
      end
    end
  end

  defp run_extraction(body, rules) do
    %Request{response: %{body: body}}
    |> RequestorPipeline.extract_data(%CrawlJob{extract: rules})
    |> Map.get(:extracted_data)
  end
end
