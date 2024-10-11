# frozen_string_literal: true

require 'CSV'
require 'roo'

module InfernoRequirementsTools
  module Tasks
    # This class manages the collection of requirements details from
    # requirements planning excel workbooks into a CSV representation.
    # Currently splits out Requirements and Planned Not Tested Requirements
    # into two separate files. 
    # 
    # The `run` method will generate the files
    # The `run_check` method will check whether the previously generated files are up-to-date.
    class CollectRequirements

      # Update these constants based on the test kit.
      TEST_KIT_ID = 'inferno-template'
      INPUT_SETS = ['inferno-template_req-tools'].freeze

      # Derivative constants
      TEST_KIT_CODE_FOLDER = TEST_KIT_ID.gsub('-', '_')
      INPUT_HEADERS =
        [
          'ID*',
          'URL*',
          'Requirement*',
          'Conformance*',
          'Actor*',
          'Sub-Requirement(s)',
          'Conditionality',
          'Verifiable?',
          'Verifiability Details',
          'Planning To Test?',
          'Planning To Test Details'
        ].freeze
      REQUIREMENTS_OUTPUT_HEADERS =
        [
          'Req Set',
          'ID',
          'URL',
          'Requirement',
          'Conformance',
          'Actor',
          'Sub-Requirement(s)',
          'Conditionality'
        ].freeze
      REQUIREMENTS_OUTPUT_FILE_NAME = "#{TEST_KIT_ID}_requirements.csv".freeze
      REQUIREMENTS_OUTPUT_FILE =
        File.join('lib', TEST_KIT_CODE_FOLDER, 'requirements', REQUIREMENTS_OUTPUT_FILE_NAME).freeze
      PLANNED_NOT_TESTED_OUTPUT_HEADERS = ['Req Set', 'ID', 'Reason', 'Details'].freeze
      PLANNED_NOT_TESTED_OUTPUT_FILE_NAME = "#{TEST_KIT_ID}_out_of_scope_requirements.csv".freeze
      PLANNED_NOT_TESTED_OUTPUT_FILE =
        File.join('lib', TEST_KIT_CODE_FOLDER, 'requirements', PLANNED_NOT_TESTED_OUTPUT_FILE_NAME).freeze

      def available_input_worksheets
        @available_input_worksheets ||= Dir.glob(File.join(@input_directory, '*.xlsx')).reject { |f| f.include?('~$') }
      end

      # Of the form:
      # {
      #   req_set_id_1: [row1, row2, row 3, ...],
      #   req_set_id_2: [row1, row2, row 3, ...]
      # }
      def input_requirement_sets
        @input_requirement_sets ||= INPUT_SETS.each_with_object({}) do |req_set_id, hash|
          req_set_file = available_input_worksheets.find { |worksheet_file| worksheet_file.include?(req_set_id) }

          hash[req_set_id] =
            unless req_set_file.nil?
              CSV.parse(Roo::Spreadsheet.open(req_set_file).sheet('Requirements').to_csv,
                        headers: true).map do |row|
                row.to_h.slice(*INPUT_HEADERS)
              end
            end
        end
      end

      def new_requirements_csv
        @new_requirements_csv ||=
          CSV.generate(+"\xEF\xBB\xBF") do |csv| # start with an unnecessary BOM to make viewing in excel easier
            csv << REQUIREMENTS_OUTPUT_HEADERS

            input_requirement_sets.each do |req_set_id, input_rows|
              input_rows.each do |input_row| # NOTE: use row order from source file
                csv << REQUIREMENTS_OUTPUT_HEADERS.map do |header|
                  header == 'Req Set' ? req_set_id : input_row[header] || input_row["#{header}*"]
                end
              end
            end
          end
      end

      def old_requirements_csv
        @old_requirements_csv ||= File.read(REQUIREMENTS_OUTPUT_FILE)
      end

      def new_planned_not_tested_csv
        @new_planned_not_tested_csv ||=
          CSV.generate(+"\xEF\xBB\xBF") do |csv| # start with an unnecessary BOM to make viewing in excel easier
            csv << PLANNED_NOT_TESTED_OUTPUT_HEADERS

            input_requirement_sets.each do |req_set_id, input_rows|
              input_rows.each do |row|
                if spreadsheet_value_falsy?(row['Verifiable?'])
                  csv << [req_set_id, row['ID*'], 'Not Verifiable', row['Verifiability Details']]
                elsif spreadsheet_value_falsy?(row['Planning To Test?'])
                  csv << [req_set_id, row['ID*'], 'Not Tested', row['Planning To Test Details']]
                end
              end
            end
          end
      end

      def old_planned_not_tested_csv
        @old_planned_not_tested_csv ||= File.read(PLANNED_NOT_TESTED_OUTPUT_FILE)
      end

      def run(input_directory)
        @input_directory = input_directory
        check_presence_of_input_files

        update_requirements =
          if File.exist?(REQUIREMENTS_OUTPUT_FILE)
            if old_requirements_csv == new_requirements_csv
              puts "'#{REQUIREMENTS_OUTPUT_FILE_NAME}' file is up to date."
              false
            else
              puts 'Requirements set has changed.'
              true
            end
          else
            puts "No existing #{REQUIREMENTS_OUTPUT_FILE_NAME}."
            true
          end

        if update_requirements
          puts "Writing to file #{REQUIREMENTS_OUTPUT_FILE}..."
          File.write(REQUIREMENTS_OUTPUT_FILE, new_requirements_csv, encoding: Encoding::UTF_8)
        end

        udpate_planned_not_tested =
          if File.exist?(PLANNED_NOT_TESTED_OUTPUT_FILE)
            if old_planned_not_tested_csv == new_planned_not_tested_csv
              puts "'#{PLANNED_NOT_TESTED_OUTPUT_FILE_NAME}' file is up to date."
              false
            else
              puts 'Planned Not Tested Requirements set has changed.'
              true
            end
          else
            puts "No existing #{PLANNED_NOT_TESTED_OUTPUT_FILE_NAME}."
            true
          end

        if udpate_planned_not_tested
          puts "Writing to file #{PLANNED_NOT_TESTED_OUTPUT_FILE}..."
          File.write(PLANNED_NOT_TESTED_OUTPUT_FILE, new_planned_not_tested_csv, encoding: Encoding::UTF_8)
        end

        puts 'Done.'
      end

      def run_check(input_directory)
        @input_directory = input_directory
        check_presence_of_input_files

        requirements_ok =
          if File.exist?(REQUIREMENTS_OUTPUT_FILE)
            if old_requirements_csv == new_requirements_csv
              puts "'#{REQUIREMENTS_OUTPUT_FILE_NAME}' file is up to date."
              true
            else
              puts "#{REQUIREMENTS_OUTPUT_FILE_NAME} file is out of date."
              false
            end
          else
            puts "No existing #{REQUIREMENTS_OUTPUT_FILE_NAME} file."
            false
          end

        planned_not_tested_requirements_ok =
          if File.exist?(PLANNED_NOT_TESTED_OUTPUT_FILE)
            if old_planned_not_tested_csv == new_planned_not_tested_csv
              puts "'#{PLANNED_NOT_TESTED_OUTPUT_FILE_NAME}' file is up to date."
              true
            else
              puts "#{PLANNED_NOT_TESTED_OUTPUT_FILE_NAME} file is out of date."
              false
            end
          else
            puts "No existing #{PLANNED_NOT_TESTED_OUTPUT_FILE_NAME} file."
            false
          end

        return if planned_not_tested_requirements_ok && requirements_ok

        puts <<~MESSAGE
          Check Failed. To resolve, run:

                bundle exec rake "requirements:collect[<input_directory>]"

        MESSAGE
        exit(1)
      end

      def check_presence_of_input_files
        input_requirement_sets.each do |req_set_id, rows|
          next unless rows.nil?

          puts %(
            Could not find input file for set #{req_set_id} in directory #{input_directory}. Aborting requirements
            collection..."
          )
          exit(1)
        end
      end

      def spreadsheet_value_falsy?(str)
        str&.downcase == 'no' || str&.downcase == 'false'
      end
    end
  end
end
