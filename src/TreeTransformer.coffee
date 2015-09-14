# Returns the first item in `l` which "matches" with `val` via `matcher`.
firstMatch = (l, val, matcher) ->
  for i in l
    if matcher i, val
      return i
  return null

class TreeTransformer
  ###
  Creates an empty `TreeTransformer`.

  @param [Function] TreeModelConstructor Dependency injection for tree models.
  ###
  constructor: (@TreeModelConstructor) ->
    @_nodeCases = []

  ###
  Adds a transform for a node which passes the supplied predicate.

  @param [Function<a, TreeModel<a>, Boolean>] predicate
  @param [Function<a, TreeModel<a>, b>] transform
  ###
  addNodeCase: (predicate, transform) ->
    nodeCase =
      predicate: predicate
      transform: transform
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
      r = new @TreeModelConstructor (nodeCase.transform model.value, model)
      # console.log 'before', (JSON.stringify model.orderedChildrenKeys)
      model.orderedChildrenKeys.forEach (key) =>
        child = model.getChild key
        transformedChild = @transform child
        if transformedChild?
          r.addChild key, transformedChild
      # console.log 'after', (JSON.stringify model.orderedChildrenKeys)
      return r
    else
      return null


  ###
  Watches the provided tree model, calling the provided function when a
  transform occurs.

  @param [TreeModel] model The model to be watched and transformed.
  @param [Function<TreeModel, TreeModel, a>] onTransform Function which will be
    called when the model is transformed, providing the transformed and
    untransformed models as parameters.
  @param [Boolean] lazy `true` if this should only update changed branches.
  @return [Function] An unsubscribe function.
  ###
  watch: (model, onTransform, lazy = true) -> switch lazy
    when false
      cb = () => onTransform (@transform model), model
      model.addEventListener 'changed', cb
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
            .replaceChild key, branch
        onTransform mostRecentResult

      model.addEventListener 'changed', cb
      return () -> model.removeEventListener 'changed', cb



module.exports = TreeTransformer