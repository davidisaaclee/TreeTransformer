TreeModel = require 'TreeModel'
TreeTransformer = require '../../build/TreeTransformer.js'

describe 'TreeTransformer', () ->
  beforeEach () ->
    @transformer = new TreeTransformer ((value) -> new TreeModel value)
    rootValue =
      name: 'root'
      type: 'a'
      foo: 3
    @model = new TreeModel rootValue

  it 'can do shallow transforms', () ->
    @transformer.addNodeCase \
      () -> true,
      (val, model) -> foo: (val.foo + 1)

    transformed = @transformer.transform @model

    expect @model.childList.length
      .toBe 0
    expect @model.value.name
      .toBe 'root'
    expect @model.value.foo
      .toBe 3

    expect transformed.childList.length
      .toBe 0
    expect transformed.value.name
      .not.toBeDefined()
    expect transformed.value.foo
      .toBe 4

  it 'can do deep transforms', () ->
    @model.put ['a'],
      foo: 0
      type: 'a'
    @model.put ['a', 'a'],
      foo: 0
      type: 'a'
    @model.put ['a', 'a', 'b'],
      foo: 0
      type: 'b'
    @model.put ['b'],
      foo: 0
      type: 'b'
    @model.put ['b', 'b'],
      foo: 0
      type: 'b'


    @transformer.addNodeCase \
      (val, model) -> val.type is 'a',
      (val, model) -> foo: (val.foo + 1)
    @transformer.addNodeCase \
      (val, model) -> val.type is 'b',
      (val, model) -> foo: (val.foo - 1)

    transformed = @transformer.transform @model

    expect @model.navigate(['a']).value.foo + 1
      .toEqual transformed.navigate(['a']).value.foo
    expect @model.navigate(['a', 'a']).value.foo + 1
      .toEqual transformed.navigate(['a', 'a']).value.foo
    expect @model.navigate(['a', 'a', 'b']).value.foo - 1
      .toEqual transformed.navigate(['a', 'a', 'b']).value.foo
    expect @model.navigate(['b']).value.foo - 1
      .toEqual transformed.navigate(['b']).value.foo
    expect @model.navigate(['b', 'b']).value.foo - 1
      .toEqual transformed.navigate(['b', 'b']).value.foo


  it 'updates watched models', () ->
    @transformer.addNodeCase \
      (val, model) -> val.type is 'a',
      (val, model) -> foo: (val.foo + 1)
    @transformer.addNodeCase \
      (val, model) -> val.type is 'b',
      (val, model) -> foo: (val.foo - 1)

    transformCallbackSpy = jasmine.createSpy 'transformCallbackSpy'
    transformedModel = null
    unsub = @transformer.watch @model, (transformed) =>
      transformedModel = transformed
      do transformCallbackSpy
      expect (@model.value.foo + 1)
        .toBe transformed.value.foo

      if @model.getChild('b')?
        expect (@model.getChild('b').value.foo - 1)
          .toBe transformed.getChild('b').value.foo

    expect transformCallbackSpy.calls.count()
      .toBe 1
    transformCallbackSpy.calls.reset()

    @model.put ['b'],
      foo: 0
      type: 'b'
    expect transformCallbackSpy.calls.count()
      .toBe 1

    @model.put ['b', 'a'],
      foo: 0
      type: 'a'
    expect transformCallbackSpy.calls.count()
      .toBe 2
    expect @model.navigate(['b', 'a']).value.foo + 1
      .toBe transformedModel.navigate(['b', 'a']).value.foo

    transformCallbackSpy.calls.reset()
    do unsub
    @model.put ['b', 'a', 'a'],
      foo: 0
      type: 'a'
    expect transformCallbackSpy.calls.count()
      .toBe 0
    expect transformedModel.navigate(['b', 'a']).getChild('a')
      .toBeNull()


  it 'maintains children order through transforms', () ->
    @model.put ['1'],
      foo: 0
      type: 'a'
    @model.put ['2'],
      foo: 0
      type: 'b'
    @model.put ['3'],
      foo: 0
      type: 'b'
    @model.put ['4'],
      foo: 0
      type: 'b'
    @model.put ['1', '10'],
      foo: 0
      type: 'a'
    @model.put ['1', '20'],
      foo: 0
      type: 'b'
    @model.put ['1', '30'],
      foo: 0
      type: 'b'

    @transformer.addNodeCase \
      (val, model) -> val.type is 'a',
      (val, model) -> foo: (val.foo + 1)
    @transformer.addNodeCase \
      (val, model) -> val.type is 'b',
      (val, model) -> foo: (val.foo - 1)

    transformed = @transformer.transform @model
    expect transformed.orderedChildrenKeys
      .toEqual ['1', '2', '3', '4']
    expect transformed.getChild('1').orderedChildrenKeys
      .toEqual ['10', '20', '30']

  it 'maintains children order through watched transforms', () ->
    @transformer.addNodeCase \
      (val, model) -> val.type is 'a',
      (val, model) -> foo: (val.foo + 1)
    @transformer.addNodeCase \
      (val, model) -> val.type is 'b',
      (val, model) -> foo: (val.foo - 1)

    transformed = null
    @transformer.watch @model, (xformd) ->
      transformed = xformd

    @model.put ['1'],
      foo: 0
      type: 'a'
    expect transformed.orderedChildrenKeys
      .toEqual ['1']

    @model.put ['2'],
      foo: 0
      type: 'b'
    expect transformed.orderedChildrenKeys
      .toEqual ['1', '2']

    @model.put ['3'],
      foo: 0
      type: 'b'
    expect transformed.orderedChildrenKeys
      .toEqual ['1', '2', '3']

    @model.put ['4'],
      foo: 0
      type: 'b'
    expect transformed.orderedChildrenKeys
      .toEqual ['1', '2', '3', '4']

    @model.put ['1', '10'],
      foo: 0
      type: 'a'
    expect transformed.getChild('1').orderedChildrenKeys
      .toEqual ['10']

    expect @model.orderedChildrenKeys
      .toEqual ['1', '2', '3', '4']
    expect transformed.orderedChildrenKeys
      .toEqual ['1', '2', '3', '4']

    # @model.put ['1', '20'],
    #   foo: 0
    #   type: 'b'
    # expect transformed.getChild('1').orderedChildrenKeys
    #   .toEqual ['10', '20']

    # @model.put ['1', '30'],
    #   foo: 0
    #   type: 'b'
    # expect transformed.getChild('1').orderedChildrenKeys
    #   .toEqual ['10', '20', '30']