# Minitest 6 dropped minitest/mock, so `Object#stub` is gone. This is the small
# piece of it the suite actually needs: swap a singleton method for the
# duration of a block and put the previous definition back afterwards.
module StubHelpers
  # The replacement comes in as a lambda so the block can be the code under
  # test: `stub_singleton(Net::HTTP, :start, ->(*) { ... }) { ... }`.
  def stub_singleton(object, name, implementation)
    singleton = object.singleton_class
    defined_here = singleton.instance_methods(false).include?(name) ||
                   singleton.private_instance_methods(false).include?(name)
    original = singleton.instance_method(name) if defined_here

    singleton.send(:define_method, name, implementation)
    yield
  ensure
    singleton.send(:remove_method, name)
    singleton.send(:define_method, name, original) if original
  end
end
