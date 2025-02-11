require_relative 'version'

module InfernoTemplate
  class Metadata < Inferno::TestKit
    id :inferno_template
    title 'Inferno Template'
    description <<~DESCRIPTION
      This is a big markdown description of the test kit.
    DESCRIPTION
    suite_ids [:inferno_template]
    # tags ['SMART App Launch', 'US Core']
    # last_updated '2024-03-07'
    version VERSION
    maturity 'Low'
    authors ['Inferno Template']
    # repo 'TODO'
  end
end
