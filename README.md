All code in this package is provided under the LGPL-3 license.
Please read the file COPYING.

Tested for MRI 2.6, 2.7

# Example Process (DSL)

```ruby
class SimpleWorkflow < WEEL
  handlerwrapper SimpleHandlerWrapper

  endpoint :ep1 => "orf.at"
  data :a => 17

  control flow do
    call :a1, :ep1, parameters: { :a => data.a, :b => 2 } do
      data.a += 3
    end
  end
end
```

HandlerWrappers are classes that implement communication protocols. Endpoints hold the communication targets and can be reused throughout the control flow. Data elements are control flow scoped variables.

# Further Reading

For a evaluation and description of all available control flow statements, see https://arxiv.org/pdf/1003.3330.pdf.
