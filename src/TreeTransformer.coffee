# Returns the first item in `l` which "matches" with `val` via `matcher`.
firstMatch = (l, val, matcher) ->
  for i in l
    if matcher i, val
      return i
  return null

class TreeTransformer
  ###
  Creates an empty `TreeTransformer`.

  @param [Function] makeDefaultTree Dependency injection for tree models. Should
    not require use of `new`.
  ###
  constructor: (@makeDefaultTree) ->
    @_nodeCases = []

  ###
  Adds a transform for a node which passes the supplied predicate.

  @param [Function<a, TreeModel<a>, Boolean>] predicate
  @param [Function<a, TreeModel<a>, b>] transform
  @param [Function<a, TreeModel<a>>] treeConstructor
  ###
  addNodeCase: (predicate, transform, treeConstructor = @makeDefaultTree) ->
    nodeCase =
      predicate: predicate
      transform: transform
      constructor: treeConstructor
    @_nodeCases.push nodeCase

  ###
  Transforms the provided tree model.

  @param [TreeModel] model The model to transform.
  @return [TreeModel] The transformed model.
  ###
  transform: (model) ->
    nodeCase = firstMatch @_nodeCases, model, ({predicate}) ->
      predicate model.value, model

    if nodeCase?
      r = nodeCase.constructor (nodeCase.transform model.value, model)
      model.orderedChildrenKeys.forEach (key) =>
        child = model.getChild key
        transformedChild = @transform child
        if transformedChild?
          r.addChild key, transformedChild
      return r
    else
      console.warn 'No case matching node ', model
      return null


  ###
  Watches the provided tree model, calling the provided function when a
  transform occurs.

  @param [TreeModel] model The model to be watched and transformed.
  @param [Function<TreeModel, TreeModel, a>] onTransform Function which will be
    called when the model is transformed, providing the transformed and
    untransformed models as parameters.
  @param [Boolean] lazy `true` if this should only update changed branches.
  @param [Boolean] transformNow `true` if this method should immediately perform
    a transform upon being called; else, wait for the first modification.
  @return [Function] An unsubscribe function.
  ###
  watch: (model, onTransform, lazy = true, transformNow = true) -> switch lazy
    when false
      cb = () => onTransform (@transform model), model
      model.addEventListener 'changed', cb

      if transformNow
        do cb

      return () -> model.removeEventListener 'changed', cb
    when true
      mostRecentResult = @transform model
      cb = ({data:{node, path}}) =>
        if path.length is 0
          mostRecentResult = @transform model
        else
          branch = @transform node
          [parentPath..., key] = path
          mostRecentResult
            .navigate parentPath
            .setChild key, branch
        onTransform mostRecentResult

      model.addEventListener 'changed', cb

      if transformNow
        onTransform mostRecentResult, model

      return () -> model.removeEventListener 'changed', cb



module.exports = TreeTransformer