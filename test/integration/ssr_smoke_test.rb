# frozen_string_literal: true

require "test_helper"
require "net/http"
require "json"
require "socket"

# Boots the Node SSR server against the built bundle, posts a page payload
# to /render, and asserts the result contains real markup. Catches drift
# between client and SSR entrypoints, broken `noExternal` resolution, and
# browser-globals-at-top-level mistakes that only surface during SSR.
class SsrSmokeTest < ActiveSupport::TestCase
  PORT = 13714
  SSR_BUNDLE = Rails.root.join("public/vite-ssr/ssr.js")
  STARTUP_TIMEOUT = 15

  setup do
    unless Rails.root.join("node_modules").exist?
      flunk "node_modules missing — run `npm install` before running SSR tests"
    end

    if port_in_use?
      flunk "Port #{PORT} is already in use; stop any running `bin/dev-ssr` " \
            "or `npm run ssr` before running this test"
    end

    unless system("bin/vite build --ssr", chdir: Rails.root.to_s)
      flunk "Failed to build SSR bundle — check `bin/vite build --ssr` output"
    end

    @ssr_pid = Process.spawn("node", SSR_BUNDLE.to_s, out: File::NULL, err: File::NULL)

    deadline = Time.now + STARTUP_TIMEOUT
    until port_in_use?
      flunk "SSR server failed to start within #{STARTUP_TIMEOUT}s" if Time.now > deadline
      sleep 0.1
    end
  end

  teardown do
    next unless @ssr_pid
    Process.kill("TERM", @ssr_pid)
    Process.wait(@ssr_pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end

  test "SSR pipeline renders a known page with real markup and head tags" do
    result = render_page("Home")

    assert_kind_of String, result["body"]
    refute_empty result["body"], "SSR returned an empty body"
    assert_includes result["body"], "Hello world",
                    "Expected SSR-rendered Home page to include 'Hello world'; got: #{result["body"][0, 300]}"

    head = Array(result["head"]).join
    assert_includes head, "<title", "Expected SSR head to include a <title> tag"

    # The results page is rendered on POST and is SSR'd in production like any
    # other page; rendering it against the same booted server guards against
    # browser globals (window, document, matchMedia) leaking into render.
    results = render_page("analyses/Results", analysis: RESULTS_ANALYSIS, inputs: RESULTS_INPUTS)
    body = results["body"]
    assert_includes body, "The seven criteria"
    assert_includes body, "$30.00", "Expected the Graham Number figure in the SSR body"
    assert_includes body, "Inputs used"
    assert_includes body, "Latest year", "Expected the inputs recap in the SSR body"
  end

  RESULTS_INPUTS = {
    ticker: "STL", company_name: "Steady Corp", financial_company: false,
    price: "24", revenue: "900", current_assets: "500", current_liabilities: "200",
    eps_1: "2.00", eps_2: "2.10", eps_3: "1.90", eps_4: "1.80", eps_5: "1.70",
    eps_6: "1.60", eps_7: "1.50", eps_8: "1.30", eps_9: "1.25", eps_10: "1.20",
    dividend_years: "25", bvps: "20"
  }.freeze

  # Shape of Graham::Checklist#to_props for worked example A (all seven pass).
  RESULTS_ANALYSIS = {
    ticker: "STL", company_name: "Steady Corp", financial_company: false, price: 24.0,
    rules: [
      { key: "adequate_size", verdict: "pass", reason: nil, values: { revenue: 900.0, threshold: 700.0 } },
      { key: "financial_condition", verdict: "pass", reason: nil,
        values: { current_ratio: 2.5, current_assets: 500.0, current_liabilities: 200.0 } },
      { key: "earnings_stability", verdict: "pass", reason: nil, values: { positive_years: 10 } },
      { key: "dividend_record", verdict: "pass", reason: nil, values: { dividend_years: 25, required_years: 20 } },
      { key: "earnings_growth", verdict: "pass", reason: nil, values: { recent_avg: 2.0, old_avg: 1.25, growth_pct: 60.0 } },
      { key: "moderate_pe", verdict: "pass", reason: nil, values: { pe: 12.0, avg_eps: 2.0, price_limit: 30.0 } },
      { key: "moderate_pb", verdict: "pass", reason: nil, values: { pb: 1.2, pe: 12.0, pe_times_pb: 14.4 } }
    ],
    pass_count: 7, fail_count: 0, na_count: 0, met_count: 7,
    graham_number: { computable: true, value: 30.0, margin_pct: 20.0, eps_used: 2.0, bvps_used: 20.0 },
    revenue_threshold: 700.0
  }.freeze

  private

  def port_in_use?
    TCPSocket.new("localhost", PORT).close
    true
  rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
    false
  end

  def render_page(component, props = {})
    body = {
      component: component,
      props: {
        current_user: nil,
        flash: { notice: nil, alert: nil },
        errors: {},
        **props
      },
      url: "/",
      version: "test",
      encryptHistory: false,
      clearHistory: false
    }.to_json

    res = Net::HTTP.post(
      URI("http://localhost:#{PORT}/render"),
      body,
      "Content-Type" => "application/json"
    )

    flunk "SSR /render returned #{res.code}: #{res.body[0, 300]}" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)
  end
end
