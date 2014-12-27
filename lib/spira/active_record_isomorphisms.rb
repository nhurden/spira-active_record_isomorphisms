require 'active_support/core_ext/object/try'
require 'active_support/core_ext/string/inflections'
require 'spira/active_record_isomorphisms/version'

module Spira
  module ActiveRecordIsomorphisms
    # Errors
    class NoDefaultVocabularyError < StandardError; end
    class IsomorphismAlreadyDefinedError < StandardError; end

    def self.included(model)
      model.extend ClassMethods
    end

    module ClassMethods
      def isomorphic_with(ar_name)
        raise NoDefaultVocabularyError, 'A default vocabulary must be set' unless default_vocabulary

        # Create the foreign key property
        id_sym = (ar_name.to_s + '_id').to_sym
        if properties.keys.include? id_sym.to_s
          raise IsomorphismAlreadyDefinedError,
            "An isomorphism with #{ar_name} has already been established or the property #{@id_sym} is already in use."
        end
        property id_sym, type: Spira::Types::Integer

        define_active_record_methods(ar_name)
        define_spira_methods(ar_name)
      end

      private

      def define_active_record_methods(ar_name)
        ar_class = model_class_for_sym(ar_name)
        spira_name = self.name.underscore.to_sym
        spira_class = self

        # Get the Spira model from the ActiveRecord model
        ar_class.send(:define_method, spira_name) do
          predicate = RDF::Vocabulary.new(spira_class.default_vocabulary)["/#{ar_name}_id"]
          object = RDF::Literal.new(id, datatype: RDF::XSD.integer)
          subject = Spira.repository.query(predicate: predicate, object: object).first.try(:subject)
          subject ? spira_class.for(subject) : nil
        end

        # Set the Spira model on the ActiveRecord model
        ar_class.send(:define_method, (spira_name.to_s + '=').to_sym) do |new_model|
          old_model = self.send(spira_name)
          id_setter_name = (ar_name.to_s + '_id=').to_sym

          # Remove id on the old Spira model
          old_model.send(id_setter_name, nil) if old_model

          # Set id on the new Spira model
          new_model.send(id_setter_name, self.id) if new_model
        end
      end

      def define_spira_methods(ar_name)
        ar_class = model_class_for_sym(ar_name)

        # Get the ActiveRecord model from the Spira model
        define_method(ar_name) do
          id = self.send((ar_name.to_s + '_id').to_sym)
          ar_class.find(id)
        end

        # Set the ActiveRecord model on the Spira model
        define_method((ar_name.to_s + '=').to_sym) do |new_model|
          method_name = (ar_name.to_s + '_id=').to_sym
          self.send(method_name, new_model.try(:id))
        end
      end

      # Convert a class name symbol to the corresponding model class
      def model_class_for_sym(model_sym)
        begin
          model_sym.to_s.classify.constantize
        rescue NameError
          raise NameError, "Cannot convert :#{model_sym} to a valid model class"
        end
      end
    end
  end

  class Base
    include ActiveRecordIsomorphisms
  end
end
