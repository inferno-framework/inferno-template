module InfernoTemplate
    class PatientReadAndSearchGroup < Inferno::TestGroup
        title 'Patient: Read and Search'
        description 'Source: https://confluence.hl7.org/pages/viewpage.action?pageId=203358353'
        id :patient_read_and_search_group

        test do
            title 'READ'
            description %(
                FHIR client retrieves the patient resource with the Id.
            )

            makes_request :patient

            run do
                patient_ids = ["wang-li", "italia-sofia"]
                for patient_id in patient_ids do
                    fhir_read(:patient, patient_id, name: :patient)
                    assert_response_status(200)
                    assert_resource_type(:patient)
                    assert resource.id == patient_id,
                            "Requested resource with id #{patient_id}, received resource with id #{resource.id}"
                end
            end
        end


        test do
            title 'SEARCH: _id'
            description %(
                FHIR client searches the FHIR server for patients with a given id
            )
            makes_request :patient

            run do
                patient_ids = ["wang-li", "italia-sofia"]
                for patient_id in patient_ids do
                    fhir_search(:patient, params: { _id: patient_id })
                    assert_response_status(200)
                    assert_resource_type(:bundle)
                    assert resource.entry.first().resource.id == patient_id,
                        "Requested resource with id #{patient_id}, received resource with id #{resource.entry.first().resource.id}"
                end
            end
        end

        test do
            title 'SEARCH identifier'
            description %(
                Find patient record using the identifier parameter "http://ns.electronichealth.net.au/id/hi/ihi/1.0|7C8003608833357361" \n
                Find patient record using the identifier parameter "http://ns.electronichealth.net.au/id/dva|NBUR9080" \n
                Find patient record using the identifier parameter "http://ns.electronichealth.net.au/id/medicare-number|1234567892
            )
            makes_request :patient

            run do
                identifier_arr = [
                    "http://ns.electronichealth.net.au/id/hi/ihi/1.0|7C8003608833357361",
                    "http://ns.electronichealth.net.au/id/dva|NBUR9080",
                    "http://ns.electronichealth.net.au/id/medicare-number|1234567892"
                ]

                for identifier in identifier_arr do
                    fhir_search(:patient, params: { _identifier: identifier })
                    assert_response_status(200)
                    assert_resource_type(:bundle)
                    assert resource.entry.length() > 0
                end
            end
        end

        test do
            title 'SEARCH: birthdate+family'
            description %(
                Find patient records using combination of birthdate parameter '1999-12-19' and family name parameter 'smith' \n
                Find patient records using combination of birthdate parameter '1968-10-11' and family name parameter 'Bennelong'
            )
            makes_request :patient

            run do
                search_param_arr = [
                    {"bd" => '1999-12-19', "family" => 'smith'},
                    {"bd" => '1968-10-11', "family" => 'Bennelong'},
                ]
                for search_param in search_param_arr do
                    birth_date_to_search = search_param["bd"]
                    family_name_to_search = search_param["family"]
                    fhir_search(:patient, params: { birthdate: birth_date_to_search, family: family_name_to_search })
                    assert_response_status(200)
                    assert_resource_type(:bundle)
                    assert resource.entry.length() > 0
                    result_bd = resource.entry.first().resource.birthDate
                    result_famility_name = resource.entry.first().resource.name.first().family
                    assert birth_date_to_search == result_bd, "Result BD #{result_bd} should be equal to #{birth_date_to_search}"
                    assert family_name_to_search.downcase == result_famility_name.downcase, "Result family name #{result_famility_name} should be equal to #{family_name_to_search}"
                end
            end
        end

        test do
            title 'SEARCH: birthdate+name'
            description %(
                Find patient records using combination of birthdate parameter '1939-08-25' and name parameter 'Dan'
            )
            makes_request :patient

            run do
                birth_date_to_search = '1939-08-25'
                name_to_search = 'Dan'
                fhir_search(:patient, params: { birthdate: birth_date_to_search, name: name_to_search })
                assert_response_status(200)
                assert_resource_type(:bundle)
                assert resource.entry.length() > 0
                result_bd = resource.entry.first().resource.birthDate
                result_name = resource.entry.first().resource.name.first().family
                assert birth_date_to_search == result_bd, "Result BD #{result_bd} should be equal to #{birth_date_to_search}"
                assert name_to_search.downcase == result_name.downcase, "Result family name #{result_name} should be equal to #{name_to_search}"
            end
        end

        test do
            title 'SEARCH: family'
            description %(
                Find patient records using family name parameter 'smith' \n
                Find patient records using family name parameter 'Bennelong'
            )
            makes_request :patient

            run do
                family_name_arr = ["smith", "Bennelong"]
                for family_name in family_name_arr do
                    family_to_search = family_name
                    fhir_search(:patient, params: { family: family_to_search })
                    assert_response_status(200)
                    assert_resource_type(:bundle)
                    assert resource.entry.length() > 0
                    result_family = resource.entry.first().resource.name.first().family
                    assert family_to_search.downcase == result_family.downcase, "Result family name #{result_family} should be equal to #{family_to_search}"
                end
            end
        end

        test do
            title 'SEARCH: family+gender'
            description %(
                Find patient records using combination of family name parameter 'smith' and gender parameter 'female' \n
                Find patient records using combination of family name parameter 'Wang' and gender parameter 'male'
            )
            makes_request :patient

            run do
                search_param_arr = [
                    {"family" => "smith", "gender" => "female"},
                    {"family" => "Wang", "gender" => "male"},
                ]
                for search_param in search_param_arr do
                    family_to_search = search_param["family"]
                    gender_to_search = search_param["gender"]
                    fhir_search(:patient, params: { family: family_to_search, gender: gender_to_search })
                    assert_response_status(200)
                    assert_resource_type(:bundle)
                    assert resource.entry.length() > 0
                    result_family = resource.entry.first().resource.name.first().family
                    result_gender = resource.entry.first().resource.gender
                    assert family_to_search.downcase == result_family.downcase, "Result family name #{result_family} should be equal to #{family_to_search}"
                    assert gender_to_search == result_gender, "Result gender #{result_gender} should be equal to #{gender_to_search}"
                end
            end
        end

        test do
            title 'SEARCH: gender+name'
            description %(
                Find patient records using combination of family name parameter 'smith' and gender parameter 'female' \n
                Find patient records using combination of family name parameter 'Wang' and gender parameter 'male'
            )
            makes_request :patient

            run do
                search_param_arr = [
                    {"name" => "smith", "gender" => "female"},
                    {"name" => "Wang", "gender" => "male"},
                ]
                for search_param in search_param_arr do
                    name_to_search = search_param["name"]
                    gender_to_search = search_param["gender"]
                    fhir_search(:patient, params: { name: name_to_search, gender: gender_to_search })
                    assert_response_status(200)
                    assert_resource_type(:bundle)
                    assert resource.entry.length() > 0
                    result_family = resource.entry.first().resource.name.first().family
                    result_gender = resource.entry.first().resource.gender
                    assert name_to_search.downcase == result_family.downcase, "Result family name #{result_family} should be equal to #{name_to_search}"
                    assert gender_to_search == result_gender, "Result gender #{result_gender} should be equal to #{gender_to_search}"
                end
            end
        end

        test do
            title 'SEARCH: name'
            description %(
                Find patient records using name parameter 'Dan' \n
                Find patient records using name parameter 'Em'
            )
            makes_request :patient

            run do
                name_to_search = 'Dan'
                fhir_search(:patient, params: { name: name_to_search })
                assert_response_status(200)
                assert_resource_type(:bundle)
                assert resource.entry.length() > 0
                result_name = resource.entry.first().resource.name.first().family
                assert name_to_search.downcase == result_name.downcase, "Result family name #{result_name} should be equal to #{name_to_search}"

                name_to_search = 'Em'
                fhir_search(:patient, params: { name: name_to_search })
                assert_response_status(200)
                assert_resource_type(:bundle)
                assert resource.entry.length() > 0
                result_name = resource.entry.first().resource.name.first().family
                assert "smith" == result_name.downcase, "Result family name #{result_name} should be equal to SMITH"
            end
        end
    end
end
