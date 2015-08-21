module CurationConcerns
  module GenericFile
    module FullTextIndexing
      extend ActiveSupport::Concern

      included do
        contains 'full_text'
      end
    end
  end
end
