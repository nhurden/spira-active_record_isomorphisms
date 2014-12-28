require 'spec_helper'

describe Spira::ActiveRecordIsomorphisms do
  before do
    Object.send(:remove_const, :User) if defined? User
    Object.send(:remove_const, :Person) if defined? Person
    Object.send(:remove_const, :IsomorphicPerson) if defined? IsomorphicPerson

    class User < ActiveRecord::Base; end

    class Person < Spira::Base
      type FOAF.Person

      configure base_uri: 'http://example.org/example/people',
        default_vocabulary: 'http://example.org/example/vocab'

      property :name, predicate: FOAF.name, type: String
    end

    class IsomorphicPerson < Person
      isomorphic_with :user
    end
  end

  let(:new_user_bob) { User.create(email: 'bob@example.com') }

  let(:bob_pair) do
    user_bob = new_user_bob
    iso_bob = IsomorphicPerson.for('bob')
    iso_bob.name = 'Bob'
    iso_bob.user = user_bob
    iso_bob.save
    [iso_bob, user_bob]
  end

  describe "defining isomorphisms" do
    context "when the ActiveRecord class does not exist" do
      it "raises an error" do
        Object.send(:remove_const, :Person) if defined? Person
        expect {
          class Person < Spira::Base
            type FOAF.Person
            configure default_vocabulary: 'http://example.org/example/vocab'
            property :name, predicate: FOAF.name, type: String

            isomorphic_with :fake_class
          end
        }.to raise_error(NameError, /:fake_class/)
      end
    end

    context "when no default_vocabulary has been set" do
      it "raises an error" do
        Object.send(:remove_const, :User) if defined? User
        Object.send(:remove_const, :Person) if defined? Person
        expect {
          class User < ActiveRecord::Base; end
          class Person < Spira::Base
            type FOAF.Person
            property :name, predicate: FOAF.name, type: String

            isomorphic_with :user
          end
        }.to raise_error(Spira::ActiveRecordIsomorphisms::NoDefaultVocabularyError)
      end
    end

    context "when the isomorphism has already been defined" do
      it "raises an error" do
        Object.send(:remove_const, :User) if defined? User
        Object.send(:remove_const, :Person) if defined? Person
        expect {
          class User < ActiveRecord::Base; end
          class Person < Spira::Base
            type FOAF.Person
            configure default_vocabulary: 'http://example.org/example/vocab'
            property :name, predicate: FOAF.name, type: String

            isomorphic_with :user
            isomorphic_with :user
          end
        }.to raise_error(Spira::ActiveRecordIsomorphisms::IsomorphismAlreadyDefinedError,
            "An isomorphism with user has already been established or the property user_id is already in use.")
      end
    end
  end

  describe "persistence" do
    it "adds a foreign key property to the Spira model when there is an isomorphism" do
      iso_bob = IsomorphicPerson.for('bob')
      expect(iso_bob.attributes.keys).to include('user_id')
    end

    it "does not add a foreign key property to the Spira model when there is no isomorphism" do
      person_bob = Person.for('bob')
      expect(person_bob.attributes.keys).to_not include('user_id')
    end
  end

  context "when an isomorphism has been established" do
    describe "setting the associated model" do
      describe "on the Spira model" do
        context "with a valid ActiveRecord model" do
          it "sets the user_id on the Spira model" do
            iso_bob = IsomorphicPerson.for('bob')
            user_bob = new_user_bob
            iso_bob.user = user_bob
            expect(iso_bob.user_id).to eq(user_bob.id)
          end
        end

        context "with an invalid ActiveRecord model" do
          it "raises an error" do
            iso_bob = IsomorphicPerson.for('bob')
            expect { iso_bob.user = "Not a user" }.to raise_error(
              Spira::ActiveRecordIsomorphisms::TypeMismatchError,
              "Expected a model of type User, but was of type String")
          end
        end
      end

      describe "on the ActiveRecord model" do
        context "with a valid Spira model" do
          it "sets the user_id on the Spira model" do
            iso_bob = IsomorphicPerson.for('bob')
            user_bob = new_user_bob
            user_bob.isomorphic_person = iso_bob
            expect(iso_bob.user_id).to eq(user_bob.id)
          end
        end

        context "with an invalid Spira model" do
          it "raises an error" do
            user_bob = new_user_bob
            expect { user_bob.isomorphic_person = "Not an person" }.to raise_error(
              Spira::ActiveRecordIsomorphisms::TypeMismatchError,
              "Expected a model of type IsomorphicPerson, but was of type String")
          end
        end
      end
    end

    describe "accessing the associated model" do
      describe "from the Spira model" do
        it "yields the correct user" do
          iso_bob, user_bob = bob_pair
          expect(iso_bob.user).to eq(user_bob)
        end
      end

      describe "from the ActiveRecord model" do
        it "yields the correct person" do
          iso_bob, user_bob = bob_pair
          expect(user_bob.isomorphic_person).to eq(iso_bob)
        end
      end
    end

    describe "accessing delegated properties" do
      context "when delegation is enabled" do
        describe "from the Spira model" do
          it "can access the email property" do
            iso_bob, user_bob = bob_pair
            expect(iso_bob.email).to eq(user_bob.email)
          end

          it "can access the encrypted_password property" do
            iso_bob, user_bob = bob_pair
            expect(iso_bob.encrypted_password).to eq(user_bob.encrypted_password)
          end
        end

        describe "from the ActiveRecord model" do
          it "can access the name property" do
            iso_bob, user_bob = bob_pair
            expect(user_bob.name).to eq(iso_bob.name)
          end
        end
      end

      context "when delegation is disabled" do
        before do
          Object.send(:remove_const, :User) if defined? User
          Object.send(:remove_const, :IsomorphicPerson) if defined? IsomorphicPerson
          Object.send(:remove_const, :IsomorphicPersonWithoutDelegation) if defined? IsomorphicPersonWithoutDelegation

          class User < ActiveRecord::Base; end

          class IsomorphicPersonWithoutDelegation < Person
            isomorphic_with :user, delegation: false
          end
        end

        let(:bob_pair_without_delegation) do
          user_bob = new_user_bob
          iso_bob = IsomorphicPersonWithoutDelegation.for('bob')
          iso_bob.name = 'Bob'
          iso_bob.user = user_bob
          iso_bob.save
          [iso_bob, user_bob]
        end

        describe "from the Spira model" do
          it "cannot access the email property" do
            iso_bob = bob_pair_without_delegation.first
            expect { iso_bob.email }.to raise_error(NoMethodError)
          end

          it "cannot access the encrypted_password property" do
            iso_bob = bob_pair_without_delegation.first
            expect { iso_bob.encrypted_password }.to raise_error(NoMethodError)
          end
        end

        describe "from the ActiveRecord model" do
          it "cannot access the name property" do
            user_bob = bob_pair_without_delegation.second
            expect { user_bob.name }.to raise_error(NoMethodError)
          end
        end
      end
    end
  end

  context "when an isomorphism has not been established" do
    describe "setting associated models" do
      describe "on the Spira model" do
        it "raises an error" do
          person_bob = Person.for('bob')
          expect { person_bob.user = new_user_bob }.to raise_error(NoMethodError)
        end
      end

      describe "on the ActiveRecord model" do
        it "raises an error" do
          user_bob = new_user_bob
          expect { user_bob.person = Person.for('bob') }.to raise_error(NoMethodError)
        end
      end
    end

    describe "accessing associated models" do
      describe "from the Spira model" do
        it "raises an error" do
          person_bob = Person.for('bob')
          expect { person_bob.user }.to raise_error(NoMethodError)
        end
      end

      describe "from the ActiveRecord model" do
        it "raises an error" do
          user_bob = new_user_bob
          expect { user_bob.person }.to raise_error(NoMethodError)
        end
      end
    end
  end
end
