# Elixir Style Guide

The most important thing to keep in mind when considering code style is that this guide is a set of recommendations, not mandates. It is designed to assist in making style choices when writing code. If there is good reason to deviate from the guide to make a section of code more understandable, and the PR reviewers approve, then there is nothing wrong with a deviation.

Precedence in the codebase takes priority over the style guide. When in doubt, follow the style of the existing code. The more consistent the codebase is, the easier it is to read.

For the most part this project follows the Elixir community driven style guide:
* [christopheradams/elixir_style_guide](https://github.com/christopheradams/elixir_style_guide)

## Additions & Exceptions

The following are additions and exceptions to the style guide that have been adopted:

* <a name="trailing-comma"></a>
  Use trailing commas when possible. This reduces the number of lines that change in a diff when adding/removing lines from a map, list, etc.
  <sup>[[link](#trailing-comma)]</sup>
  ```elixir
  %{
    foo: 1,
    bar: 2,
    baz: 3,
  }
  ```

* <a name="align-symbols"></a>
  Align equals signs (`=`), function pointers (`->`), hashrockets (`=>`), and other similar symbols on the same column when they appear on consecutive lines.
  <sup>[[link](#align-symbols)]</sup>
  ```elixir
  some_value    = 1
  another_value = 2
  final_value   = 3
  ```

* <a name="align-values"></a>
  Align the values of maps, keyword lists, defstructs, and similar structures on the same column.
  <sup>[[link](#align-values)]</sup>
  ```elixir
  %{
    first_key:  1,
    second_key: 2,
    last_key:   3,
  }
  ```

* <a name="use-caution-with-if"></a>
  Use caution when using `if`, as it is a macro and may result in unexpected behavior when assigning values. When in doubt, use `case` instead of `if`.
  <sup>[[link](#use-caution-with-if)]</sup>
  ```elixir
  foo = "bar"

  foo =
    case condition do
      true -> foo |> transform
      _    -> foo
    end
  ```

* <a name="single-pipeline-ok"></a>
  It is ok to use the pipe operator just once. This can be useful when wanting to emphasize a transformation.
  <sup>[[link](#single-pipeline-ok)]</sup>
  <sup>[[original](https://github.com/christopheradams/elixir_style_guide#avoid-single-pipelines)]</sup>
  ```elixir
  templated_field |> StringTemplate.process(message)
  ```

* <a name="multiline-pipeline-assignment"></a>
  When assigning the output of a multiline pipeline to a variable, place the pipeline portion under the assignment and indent two spaces.
  <sup>[[link](#multiline-pipeline-assignment)]</sup>
  ```elixir
  transformed_string =
    some_string
    |> String.strip()
    |> String.downcase()
    |> String.codepoints()
  ```

* <a name="single-line-comments"></a>
  It is ok to place comments on the same line as the code when providing descriptions of tightly packed elements, like in `defstructs`, maps (`%{}`), etc.
  <sup>[[link](#single-line-comments)]</sup>
  <sup>[[original](https://github.com/christopheradams/elixir_style_guide#comments-above-line)]</sup>
  ```elixir
  defstruct \
    foo: nil, # An ISO 8601 timestamp with millisecond precision.
    bar: nil, # A string with max length of 255 characters.
    baz: nil  # A non-negative integer.
  ```

* <a name="union-types"></a>
  If a union type is too long to fit on a single line, put each part of the type on a separate line, indenting the pipe characters by two spaces and aligning the type names.
  <sup>[[link](#union-types)]</sup>
  <sup>[[original](https://github.com/christopheradams/elixir_style_guide#union-types)]</sup>
  ```elixir
  @type t ::
      ComponentTypes.AMQPOutput
    | ComponentTypes.CommandOutput
    | ComponentTypes.Condition
  ```

* <a name="multiline-defstruct"></a>
  If a struct definition spans multiple lines, add a `\` after `defstruct` and indent the following lines two spaces.
  <sup>[[link](#multiline-defstruct)]</sup>
  <sup>[[original](https://github.com/christopheradams/elixir_style_guide#multiline-structs)]</sup>
  ```elixir
  defstruct \
    foo: 1,
    bar: 2,
    baz: 3
  ```

* <a name="nil-struct-field"></a>
  Use [keywords](https://hexdocs.pm/elixir/Keyword.html) for struct fields that default to `nil`.
  <sup>[[link](#nil-struct-field)]</sup>
  <sup>[[original](https://github.com/christopheradams/elixir_style_guide#nil-struct-field-defaults)]</sup>
  ```elixir
  defstruct \
    foo: nil,
    bar: nil,
    baz: 123
  ```

* <a name="spec-it-specify"></a>
  Use `it` or `specify` in the test suite depending on which one makes grammatical sense. `it` is preferred unless it is difficult to phrase a sentence around it.
  <sup>[[link](#spec-it-specify)]</sup>
  ```elixir
  it "returns a 202 response on success"
  ```

  ```elixir
  specify "the input is invalid"
  ```
