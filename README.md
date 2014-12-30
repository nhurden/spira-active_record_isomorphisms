# spira-active\_record\_isomorphisms

Establish isomorphisms between your Spira and ActiveRecord models.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'spira-active_record_isomorphisms'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install spira-active_record_isomorphisms

## Usage

### Defining Isomorphisms

Isomorphisms are established by adding an `isomorphic_with` call to your
Spira model declaration. For example, given an ActiveRecord `User` model:
```ruby
class User < ActiveRecord::Base; end
```
with `id`, `email` and `encrypted_password` properties, an isomorphic Spira `Person` model can be defined:
```ruby
class Person < Spira::Base
  configure base_uri: 'http://example.org/example/people',
            default_vocabulary: 'http://example.org/example/vocab'

  isomorphic_with :user
  property :name, predicate: FOAF.name, type: String
end
```

### Associating Models

Models can be associated by setting the corresponding attributes:
```irb
> bob = Person.for('bob')
=> <Person:2202810640 @subject: http://example.org/example/people/bob>
> bob.user = User.find(1)
=> #<User id: 1, email: "bob@example.com", ...>
> bob.user
=> #<User id: 1, email: "bob@example.com", ...>
> bob.save
=> <Person:2202810640 @subject: http://example.org/example/people/bob>
> User.find(1).person
=> <Person:2202810640 @subject: http://example.org/example/people/bob>
> bob.user_id
=> 1
```

Note that:

- A `default_vocabulary` must be set on the Spira model.
- The Spira model must be saved before the reverse association can be
  accessed.
- The two classes must have different names.
- An id property is added to the Spira model corresponding to the name
  of the ActiveRecord model (in this case `user_id`).

### Delegated Attributes

By default, attributes are delegated in both directions:
```irb
> bob = Person.for('bob')
=> <Person:2202810640 @subject: http://example.org/example/people/bob>
> bob.user = User.find(1)
=> #<User id: 1, email: "bob@example.com", ...>
> bob.email
=> "bob@example.com"
> bob.name = 'Bob'
=> "Bob"
> User.find(1).name
=> "Bob"
```

This can be disabled by setting `delegation` to `false`: `isomorphic_with :user, delegation: false`

## Contributing

1. Fork it ( https://github.com/nhurden/spira-active\_record\_isomorphisms/fork )
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request
