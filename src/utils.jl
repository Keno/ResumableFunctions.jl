using MacroTools
using MacroTools: flatten, postwalk

"""
Function returning the arguments of a function definition
"""
function get_arguments(expr) :: Vector{Symbol}
  args = Symbol[]
  kws = Symbol[]
  params = Symbol[]
  expr_args = expr.args[1].head == :call ? expr.args[1].args : expr.args[1].args[1].args
  for arg in expr_args
    if isa(arg, Symbol)
      push!(args, arg)
    elseif arg.head == Symbol("::")
      push!(args, arg.args[1])
    elseif arg.head == :kw
      isa(arg.args[1], Symbol) ? push!(kws, arg.args[1]) : push!(kws, arg.args[1].args[1])
    elseif arg.head == :parameters
      for arg2 in arg.args
        isa(arg2.args[1], Symbol) ? push!(params, arg2.args[1]) : push!(params, arg2.args[1].args[1])
      end
    end
  end
  [args; kws; params]
end

"""
Function returning the slots of a function definition
"""
function get_slots(func_def::Dict) :: Dict{Symbol, Type}
  slots = Dict{Symbol, Type}()
  func_def[:name] = gensym()
  func_expr = combinedef(func_def) |> flatten
  func = Main.eval(func_expr)
  code_data_infos = @eval code_typed(Main.$(func_def[:name]))
  (code_info, data_type) = code_data_infos[1]
  for (i, slotname) in enumerate(code_info.slotnames)
    slots[slotname] = code_info.slottypes[i]
  end
  postwalk(x->remove_catch_exc(x, slots), func_def[:body])
  postwalk(x->make_arg_any(x, slots), func_def[:body])
  delete!(slots, Symbol("#temp#"))
  delete!(slots, Symbol("#unused#"))
  delete!(slots, Symbol("#self#"))
  slots
end

"""
Function removing the `exc` symbol of a `catch exc` statement of a list of slots.
"""
function remove_catch_exc(expr, slots::Dict{Symbol, Type})
  @capture(expr, (try body__ catch exc_; handling__ end) | (try body__ catch exc_; handling__ finally always__ end)) && delete!(slots, exc)
  expr
end

"""
Function changing the type of a slot `arg` of a `arg = @yield ret` or `arg = @yield` statement to `Any`.
"""
function make_arg_any(expr, slots::Dict{Symbol, Type})
  @capture(expr, (arg_ = @yield ret_) | (arg_ = @yield)) || return expr
  slots[arg] = Any
  expr
end
