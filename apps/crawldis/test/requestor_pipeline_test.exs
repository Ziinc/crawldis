defmodule Crawldis.RequestorPipelineTest do
  @moduledoc false
  use Crawldis.CrawlCase
  alias Crawldis.RequestorPipeline
  alias Crawldis.Request
  alias Crawldis.CrawlJob

  describe "extract_data/1 css" do
    test "can select normal node" do
      req = %Request{
        response: %{
          body: """
          <html>
            <div>123 <span>testing</span></div>
            <div>345</div>
          </html>
          """
        }
      }

      job = %CrawlJob{extract: %{"my_data" => %{"value" => "css: div span"}}}

      assert %{
               extracted_data: %{
                 "my_data" => %{"value" => "testing"}
               }
             } = RequestorPipeline.extract_data(req, job)
    end

    test "can select multiple nodes" do
      req = %Request{
        response: %{
          body: """
          <html>
            <div>123 <span>testing</span></div>
            <div>345 <span>tester</span></div>
          </html>
          """
        }
      }

      job = %CrawlJob{extract: %{"my_data" => %{"value" => ["css: div span"]}}}

      assert %{
               extracted_data: %{
                 "my_data" => %{"value" => [_, _]}
               }
             } = RequestorPipeline.extract_data(req, job)
    end

    test "can select node attributes" do
      req = %Request{
        response: %{
          body: """
          <html>
            <div>123 <span data-field="abc"">testing</span></div>
          </html>
          """
        }
      }

      job = %CrawlJob{
        extract: %{
          "my_data" => %{"value" => "css: div span::attr('data-field')"}
        }
      }

      assert %{
               extracted_data: %{
                 "my_data" => %{"value" => "abc"}
               }
             } = RequestorPipeline.extract_data(req, job)
    end

    test "can select multiple node attributes" do
      req = %Request{
        response: %{
          body: """
          <html>
            <div>123 <span data-field="abc"">testing</span></div>
            <div>123 <span data-field="def"">testing</span></div>
          </html>
          """
        }
      }

      job = %CrawlJob{
        extract: %{
          "my_data" => %{"value" => ["css: div span::attr('data-field')"]}
        }
      }

      assert %{
               extracted_data: %{
                 "my_data" => %{"value" => [_, _]}
               }
             } = RequestorPipeline.extract_data(req, job)
    end
  end
end
