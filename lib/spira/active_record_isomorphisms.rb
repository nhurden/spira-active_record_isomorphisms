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
        raise NoDefaultVocabularyError, 'A default vocabulary must be set.' unless default_vocabulary

        # Define the foreign key property
        id_sym = id_getter(ar_name)
        if properties.keys.include? id_sym.to_s
          raise IsomorphismAlreadyDefinedError,
            "An isomorphism with #{ar_name} has already been established or the property #{id_sym} is already in use."
        end
        property id_sym, type: Spira::Types::Integer

        define_active_record_methods(ar_name)
        define_spira_methods(ar_name)
      end

      private

      def append_to_symbol(symbol, suffix)
        (symbol.to_s + suffix).to_sym
      end

      def setter(name)
        append_to_symbol(name, '=')
      end

      def id_getter(name)
        append_to_symbol(name, '_id')
      end

      def id_setter(name)
        append_to_symbol(name, '_id=')
      end

      def define_active_record_methods(ar_name)
        ar_class = model_class_for_sym(ar_name)
        spira_class = self
        spira_name = spira_class.name.underscore.to_sym

        # Get the Spira model from the ActiveRecord model by querying the repository
        ar_class.send(:define_method, spira_name) do
          predicate = RDF::Vocabulary.new(spira_class.default_vocabulary)["/#{ar_name}_id"]
          object = RDF::Literal.new(id, datatype: RDF::XSD.integer)
          model_iri = Spira.repository.query(predicate: predicate, object: object).first.try(:subject)
          model_iri ? spira_class.for(model_iri) : nil
        end

        # Set the Spira model on the ActiveRecord model by updating ids on the Spira models
        id_setter_name = id_setter(ar_name)
        ar_class.send(:define_method, setter(spira_name)) do |new_model|
          old_model = self.send(spira_name)
          old_model.send(id_setter_name, nil) if old_model
          new_model.send(id_setter_name, self.id) if new_model
        end
      end

      def define_spira_methods(ar_name)
        ar_class = model_class_for_sym(ar_name)

        # Get the ActiveRecord model from the Spira model
        id_getter_name = id_getter(ar_name)
        define_method(ar_name) do
          id = self.send(id_getter_name)
          ar_class.find(id)
        end

        # Set the ActiveRecord model on the Spira model
        id_setter_name = id_setter(ar_name)
        define_method(setter(ar_name)) do |new_model|
          self.send(id_setter_name, new_model.try(:id))
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
