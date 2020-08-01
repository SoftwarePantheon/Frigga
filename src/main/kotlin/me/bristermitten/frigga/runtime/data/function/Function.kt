package me.bristermitten.frigga.runtime.data.function

import me.bristermitten.frigga.runtime.FriggaContext
import me.bristermitten.frigga.runtime.Stack
import me.bristermitten.frigga.runtime.THIS_NAME
import me.bristermitten.frigga.runtime.data.CommandNode
import me.bristermitten.frigga.runtime.data.Value
import me.bristermitten.frigga.runtime.error.BreakException
import me.bristermitten.frigga.runtime.type.Type

data class Function(
    val name: String,
    val signature: Signature,
    val content: List<CommandNode>
)
{

    internal var scope: FriggaContext? = null
    fun init(context: FriggaContext)
    {
        this.scope = context.copy()
    }

    fun call(upon: Value?, stack: Stack, context: FriggaContext, params: List<Value>)
    {
        val namedParams = signature.params.entries.mapIndexed { index, entry ->
            entry.key to params[index]
        }.toMap()

        call(upon, stack, context, namedParams)
    }

    fun call(upon: Value?, stack: Stack, context: FriggaContext, params: Map<String, Value>)
    {
        val context = scope?.copy()?.apply {
            use(context)
        } ?: context
        context.enterFunctionScope(name)

        if (upon != null) //should this ever BE null?
        {
            context.defineProperty(THIS_NAME, upon, true)
        }

        val parameters = signature.params.mapValues {

            val param = requireNotNull(params[it.key]) {
                "No value provided for parameter ${it.key}"
            }

            require(it.value.accepts(param.type)) {
                "Cannot use value of Type ${param.type} in place of ${it.value} for parameter ${it.key}"
            }

            param.type.coerceTo(param, it.value)
        }
        parameters.forEach {
            context.defineParameter(it.key, it.value)
        }

        for (it in content)
        {
            try
            {
                it.command.eval(stack, context)
            } catch (breakException: BreakException)
            {
                if (name != "yield" && name != "break" && name != "if")
                { //TODO replace with something a bit more extendable. annotations perhaps?
                    break
                }
                throw breakException
            }
        }

        context.exitScope()
    }
}

data class Signature(
    val typeSignature: Map<String, Type>,
    val params: Map<String, Type>,
    val returned: Type
)
{

    fun matches(other: Signature): Boolean
    {
        if (!other.returned.accepts(this.returned))
        {
            return false
        }

        if (params.size != other.params.size)
        {
            return false
        }

        val thisParams = params.values.toList()
        val otherParams = other.params.values.toList()

        return thisParams.withIndex().all {
            it.value.accepts(otherParams[it.index])
        }
    }

    fun typesMatch(others: List<Type>): Boolean
    {
        val thisParams = params.values.toList()

        if (this.params.isEmpty() && others.isEmpty())
        {
            return true
        }
        if (thisParams.size != others.size)
        {
            return false
        }

        return thisParams.withIndex().all {
            it.value.accepts(others[it.index])
        }
    }
}
