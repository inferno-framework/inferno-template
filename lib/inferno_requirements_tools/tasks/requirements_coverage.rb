# frozen_string_literal: true

require 'CSV'
require_relative '../ext/inferno_core/runnable'

module InfernoRequirementsTools
  module Tasks
    # This class manages the mapping of test kit tests to requirements that they verify
    # and creates a CSV file with the tests that cover each requirement.
    # It expects a CSV file in the repo at `lib/[test kit id]/requirements/[test kit id]_requirements.csv`
    # that serves as the source of the requirement set for the test kit. The requirements in
    # this files are identified by a requirement set and an id and tests, groups, and suites
    # within in the test kit can claim that they verify a requirement by including a reference
    # to that requirementin the form <requirement set>@<id> in their `verifies_requirements` field.
    # Requirements that are out of scope can be listed in a companion file
    # `lib/[test kit id]/requirements/[test kit id]_out_of_scope_requirements.csv`.
    #
    # The `run` method generates a CSV file at 
    # `lib/[test kit id]/requirements/generated/[test kit id]_requirements_coverage.csv``.
    # This file will be identical to the input spreadsheet, plus an additional column which holds a comma separated
    # list of inferno test IDs that test each requirement. These test IDs are Inferno short form IDs that represent the
    # position of the test within its group and suite. For example, the fifth test in the second group will have an ID
    # of 2.05. This ID is also shown in the Inferno web UI.
    #
    # The `run_check` method will check whether the previously generated file is up-to-date.
    class RequirementsCoverage
      
      # Update these constants based on the test kit.
      TEST_KIT_ID = 'inferno-template'
      TEST_SUITES = [InfernoTemplate::Suite].freeze # list of suite classes, including modules
      SUITE_ID_TO_ACTOR_MAP = {
        'inferno_template_test_suite' => 'Server'
      }.freeze

      # Derivative constants
      TEST_KIT_CODE_FOLDER = TEST_KIT_ID.gsub('-', '_')
      INPUT_HEADERS = [
        'Req Set',
        'ID',
        'URL',
        'Requirement',
        'Conformance',
        'Actor',
        'Sub-Requirement(s)',
        'Conditionality'
      ].freeze
      SHORT_ID_HEADER = 'Short ID(s)'
      FULL_ID_HEADER = 'Full ID(s)'
      INPUT_FILE_NAME = "#{TEST_KIT_ID}_requirements.csv".freeze
      INPUT_FILE = File.join('lib', TEST_KIT_CODE_FOLDER, 'requirements', INPUT_FILE_NAME).freeze
      NOT_TESTED_FILE_NAME = "#{TEST_KIT_ID}_out_of_scope_requirements.csv".freeze
      NOT_TESTED_FILE = File.join('lib', TEST_KIT_CODE_FOLDER, 'requirements', NOT_TESTED_FILE_NAME).freeze
      OUTPUT_HEADERS = INPUT_HEADERS + TEST_SUITES.flat_map do |suite|
                                         ["#{suite.title} #{SHORT_ID_HEADER}", "#{suite.title} #{FULL_ID_HEADER}"]
                                       end
      OUTPUT_FILE_NAME = "#{TEST_KIT_ID}_requirements_coverage.csv".freeze
      OUTPUT_FILE_DIRECTORY = File.join('lib', TEST_KIT_CODE_FOLDER, 'requirements', 'generated')
      OUTPUT_FILE = File.join(OUTPUT_FILE_DIRECTORY, OUTPUT_FILE_NAME).freeze

      def input_rows
        @input_rows ||=
          CSV.parse(File.open(INPUT_FILE, 'r:bom|utf-8'), headers: true).map do |row|
            row.to_h.slice(*INPUT_HEADERS)
          end
      end

      def not_tested_requirements_map
        @not_tested_requirements_map ||= load_not_tested_requirements
      end

      def load_not_tested_requirements
        return {} unless File.exist?(NOT_TESTED_FILE)

        not_tested_requirements = {}
        CSV.parse(File.open(NOT_TESTED_FILE, 'r:bom|utf-8'), headers: true).each do |row|
          row_hash = row.to_h
          not_tested_requirements["#{row_hash['Req Set']}@#{row_hash['ID']}"] = row_hash
        end

        not_tested_requirements
      end

      # Of the form:
      # {
      #     'req-id-1': [
      #       { short_id: 'short-id-1', full_id: 'long-id-1', suite_id: 'suite-id-1' },
      #       { short_id: 'short-id-2', full_id: 'long-id-2', suite_id: 'suite-id-2' }
      #     ],
      #     'req-id-2': [{ short_id: 'short-id-3', full_id: 'long-id-3', suite_id: 'suite-id-3' }],
      #     ...
      # }
      def inferno_requirements_map
        @inferno_requirements_map ||= TEST_SUITES.each_with_object({}) do |suite, requirements_map|
          serialize_requirements(suite, 'suite', suite.id, requirements_map)
          suite.groups.each do |group|
            map_group_requirements(group, suite.id, requirements_map)
          end
        end
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      def new_csv
        @new_csv ||=
          CSV.generate(+"\xEF\xBB\xBF") do |csv|
            csv << OUTPUT_HEADERS
            input_rows.each do |row| # NOTE: use row order from source file
              next if row['Conformance'] == 'DEPRECATED' # filter out deprecated rows

              TEST_SUITES.each do |suite|
                suite_actor = SUITE_ID_TO_ACTOR_MAP[suite.id]
                if row['Actor']&.include?(suite_actor)
                  set_and_req_id = "#{row['Req Set']}@#{row['ID']}"
                  suite_requirement_items = inferno_requirements_map[set_and_req_id]&.filter do |item|
                    item[:suite_id] == suite.id
                  end
                  short_ids = suite_requirement_items&.map { |item| item[:short_id] }
                  full_ids = suite_requirement_items&.map { |item| item[:full_id] }
                  if short_ids.blank? && not_tested_requirements_map.key?(set_and_req_id)
                    row["#{suite.title} #{SHORT_ID_HEADER}"] = 'Not Tested'
                    row["#{suite.title} #{FULL_ID_HEADER}"] = 'Not Tested'
                  else
                    row["#{suite.title} #{SHORT_ID_HEADER}"] = short_ids&.join(', ')
                    row["#{suite.title} #{FULL_ID_HEADER}"] = full_ids&.join(', ')
                  end
                else
                  row["#{suite.title} #{SHORT_ID_HEADER}"] = 'NA'
                  row["#{suite.title} #{FULL_ID_HEADER}"] = 'NA'
                end
              end

              csv << row.values
            end
          end
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def input_requirement_ids
        @input_requirement_ids ||= input_rows.map { |row| "#{row['Req Set']}@#{row['ID']}" }
      end

      # The requirements present in Inferno that aren't in the input spreadsheet
      def unmatched_requirements_map
        @unmatched_requirements_map ||= inferno_requirements_map.except(*input_requirement_ids)
      end

      def old_csv
        @old_csv ||= File.read(OUTPUT_FILE)
      end

      def run
        unless File.exist?(INPUT_FILE)
          puts "Could not find input file: #{INPUT_FILE}. Aborting requirements coverage generation..."
          exit(1)
        end

        if unmatched_requirements_map.any?
          puts "WARNING: The following requirements indicated in the test kit are not present in #{INPUT_FILE_NAME}"
          output_requirements_map_table(unmatched_requirements_map)
        end

        if File.exist?(OUTPUT_FILE)
          if old_csv == new_csv
            puts "'#{OUTPUT_FILE_NAME}' file is up to date."
            return
          else
            puts 'Requirements coverage has changed.'
          end
        else
          puts "No existing #{OUTPUT_FILE_NAME}."
        end

        puts "Writing to file #{OUTPUT_FILE}..."
        FileUtils.mkdir_p(OUTPUT_FILE_DIRECTORY)
        File.write(OUTPUT_FILE, new_csv)
        puts 'Done.'
      end

      def run_check
        unless File.exist?(INPUT_FILE)
          puts "Could not find input file: #{INPUT_FILE}. Aborting requirements coverage check..."
          exit(1)
        end

        if unmatched_requirements_map.any?
          puts "The following requirements indicated in the test kit are not present in #{INPUT_FILE_NAME}"
          output_requirements_map_table(unmatched_requirements_map)
        end

        if File.exist?(OUTPUT_FILE)
          if old_csv == new_csv
            puts "'#{OUTPUT_FILE_NAME}' file is up to date."
            return unless unmatched_requirements_map.any?
          else
            puts <<~MESSAGE
              #{OUTPUT_FILE_NAME} file is out of date.
              To regenerate the file, run:

                  bundle exec rake requirements:generate_coverage

            MESSAGE
          end
        else
          puts <<~MESSAGE
            No existing #{OUTPUT_FILE_NAME} file.
            To generate the file, run:

                  bundle exec rake requirements:generate_coverage

          MESSAGE
        end

        puts 'Check failed.'
        exit(1)
      end

      def map_group_requirements(group, suite_id, requirements_map)
        serialize_requirements(group, group.short_id, suite_id, requirements_map)
        group.tests&.each { |test| serialize_requirements(test, test.short_id, suite_id, requirements_map) }
        group.groups&.each { |subgroup| map_group_requirements(subgroup, suite_id, requirements_map) }
      end

      def serialize_requirements(runnable, short_id, suite_id, requirements_map)
        runnable.verifies_requirements&.each do |requirement_id|
          requirement_id_string = requirement_id.to_s

          requirements_map[requirement_id_string] ||= []
          requirements_map[requirement_id_string] << { short_id:, full_id: runnable.id, suite_id: }
        end
      end

      # Output the requirements in the map like so:
      #
      # requirement_id | short_id   | full_id
      # ---------------+------------+----------
      # req-id-1       | short-id-1 | full-id-1
      # req-id-2       | short-id-2 | full-id-2
      #
      # rubocop:disable Metrics/CyclomaticComplexity
      def output_requirements_map_table(requirements_map)
        headers = %w[requirement_id short_id full_id]
        col_widths = headers.map(&:length)
        col_widths[0] = [col_widths[0], requirements_map.keys.map(&:length).max].max
        col_widths[1] = ([col_widths[1]] + requirements_map.values.flatten.map { |item| item[:short_id].length }).max
        col_widths[2] = ([col_widths[2]] + requirements_map.values.flatten.map { |item| item[:full_id].length }).max
        col_widths.map { |width| width + 3 }

        puts [
          headers[0].ljust(col_widths[0]),
          headers[1].ljust(col_widths[1]),
          headers[2].ljust(col_widths[2])
        ].join(' | ')
        puts col_widths.map { |width| '-' * width }.join('-+-')
        requirements_map.each do |requirement_id, runnables|
          runnables.each do |runnable|
            puts [
              requirement_id.ljust(col_widths[0]),
              runnable[:short_id].ljust(col_widths[1]),
              runnable[:full_id].ljust(col_widths[2])
            ].join(' | ')
          end
        end
        puts
      end
      # rubocop:enable Metrics/CyclomaticComplexity
    end
  end
end
