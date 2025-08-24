defmodule Crawldis.RequestorPipelineTest do
  @moduledoc false
  use Crawldis.CrawlCase, async: true
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

  describe "regex" do
    test "top level rule without grouping" do
      body = """
      <html>
        <div>omg 123 testing</div>
        <div>omg 345 testing</div>
      </html>
      """

      rule = "regex: omg [0-9]+ "

      rules = %{
        "my_data" => %{
          "single" => rule,
          "multi" => [rule]
        }
      }

      assert %{
               "my_data" => %{
                 "single" => "omg 123",
                 "multi" => [_, _] = values
               }
             } = run_extraction(body, rules)

      assert "omg 123" in values and "omg 345" in values
    end

    test "top level rule with grouping" do
      body = """
      <html>
        <div>omg 123 testing</div>
        <div>omg 345 testing</div>
      </html>
      """

      rule = "regex: omg ([0-9]+) "

      rules = %{
        "my_data" => %{
          "single" => rule,
          "multi" => [rule]
        }
      }

      assert %{
               "my_data" => %{
                 "single" => "123",
                 "multi" => [_, _] = values
               }
             } = run_extraction(body, rules)

      assert "123" in values and "345" in values
    end
  end

  test "chaining" do
    body = """
    <html>
      <div>omg 123 testing 123</div>
      <div other="value">123
        <span data-field="abc">testing 1234 and testin 1236</span>
        <span data-field="def">testing 134 and testing 236</span>
      </div>
      <div other="testing">123 <span data-field="abc">testing 134 and testing 1336</span></div>
      <div>123 <span data-field="abc">testing</span></div>
      </html>
    """

    rule =
      "css: div[other='value'] |> css:span[data-field='abc'] |> regex: testing ([1-4]+)"

    rules = %{
      "my_data" => %{
        "single" => rule,
        "multi" => [rule]
      }
    }

    assert %{
             "my_data" => %{
               "single" => "1234",
               "multi" => ["1234"]
             }
           } = run_extraction(body, rules)
  end

  defp run_extraction(body, rules) do
    %Request{response: %{body: body}}
    |> RequestorPipeline.extract_data(%CrawlJob{extract: rules})
    |> Map.get(:extracted_data)
  end

  describe "follow_links" do
    test "follow fully qualified url" do
      body = """
        <a href="https://www.my-domain.com/some-other-path">testing</a>
      """

      assert [_] = do_follow_links(body, ["css: a::attr('href')"])
    end

    test "follow root domain" do
      body = """
        <a href="https://my-domain.com/some-other-path">testing</a>
      """

      assert [_] =
               do_follow_links(
                 body,
                 ["css: a::attr('href')"],
                 "https://www.my-domain.com"
               )
    end

    test "follow www domain" do
      body = """
        <a href="https://www.my-domain.com/some-other-path">testing</a>
      """

      assert [_] =
               do_follow_links(
                 body,
                 ["css: a::attr('href')"],
                 "https://my-domain.com"
               )
    end

    test "does not follow other domain" do
      body = """
        <a href="https://www.other-my-domain.com/some-other-path">testing</a>
      """

      assert [] =
               do_follow_links(
                 body,
                 ["css: a::attr('href')"],
                 "https://my-domain.com"
               )
    end

    test "handles relative paths" do
      body = """
        <a href="/some-other-path?some=query">testing</a>
      """

      assert ["https://www.my-domain.com/some-other-path?some=query"] =
               do_follow_links(
                 body,
                 ["css: a::attr('href')"],
                 "https://www.my-domain.com"
               )
    end
  end

  defp do_follow_links(body, rules, url \\ "https://www.my-domain/some-website") do
    %Request{url: url, response: %{body: body}}
    |> RequestorPipeline.follow_links(%CrawlJob{follow_rules: rules})
    |> Map.get(:follow_links)
  end
end
