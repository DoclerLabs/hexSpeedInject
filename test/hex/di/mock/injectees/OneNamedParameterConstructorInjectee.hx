package hex.di.mock.injectees;

/**
 * ...
 * @author Francis Bourre
 */
class OneNamedParameterConstructorInjectee implements IInjectorContainer
{
	var m_dependency : Clazz;

	@Inject( "namedDependency" )
	public function new( dependency : Clazz )
	{
		this.m_dependency = dependency;
	}
	
	public function getDependency() : Clazz
	{
		return m_dependency;
	}
}