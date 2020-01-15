package hex.di;

import hex.collection.ArrayMap;
import hex.di.IDependencyInjector;
import hex.di.IInjectorListener;
import hex.di.error.InjectorException;
import hex.di.error.MissingMappingException;
import hex.di.mapping.InjectionMapping;
import hex.di.provider.IDependencyProvider;
import hex.event.ITrigger;
import hex.event.ITriggerOwner;
import hex.log.LogManager;
import hex.util.ClassUtil;

using hex.error.Error;

/**
 * ...
 * @author Francis Bourre
 */
class Injector
	#if !macro
	implements ITriggerOwner
	#end
	implements IDependencyInjector
{
	var _mapping				: Map<String,InjectionMapping<Dynamic>>;
	var _processedMapping 		: Map<String,Bool>;
	var _managedObjects			: ArrayMap<Dynamic, Dynamic>;
	var _parentInjector			: Injector;
	
	public var trigger ( default, never ) : ITrigger<IInjectorListener>;

	public function new() 
	{
		this._mapping 			= new Map();
		this._processedMapping 	= new Map();
		this._managedObjects 	= new ArrayMap();
	}

	public function createChildInjector() : Injector
	{
		var injector 				= new Injector();
		injector._parentInjector 	= this;
		return injector;
	}

	public function addListener( listener: IInjectorListener ) : Bool
	{
		return this.trigger.connect( listener );
	}
	
	public function removeListener( listener: IInjectorListener ) : Bool
	{
		return this.trigger.disconnect( listener );
	}

	public function mapToValue<T>( clazz : ClassRef<T>, value : T, ?name : MappingName ) : Void
	{
		this.map( clazz, name ).toValue( value );
	}

	public function mapToType<T>( clazz : ClassRef<T>, type : Class<T>, ?name:MappingName ) : Void
	{
		this.map( clazz, name ).toType( type );
	}

	public function mapToSingleton<T>( clazz : ClassRef<T>, type : Class<T>, ?name:MappingName ) : Void
	{
		this.map( clazz, name ).toSingleton( type );
	}

    public function getInstance<T>( type : ClassRef<T>, ?name : MappingName, targetType : Class<Dynamic> = null ) : T
	{
		var mappingID = this._getMappingID( type, name );
		var mapping = this._mapping[ mappingID ];

		if ( mapping != null )
		{
			return mapping.getResult( targetType );
		}
		else if ( this._parentInjector != null )
		{
			return this._parentInjector.getInstance( type, name, targetType );
		}
		else
		{
			throw new MissingMappingException( 	"Injector is missing a mapping to get instance with type '" +
												Type.getClassName( type ) + "'. Target dependency: '" + mappingID + "'" );
		}
	}
	
	public function getInstanceWithClassName<T>( className : ClassName, ?name : MappingName, targetType : Class<Dynamic> = null, shouldThrowAnError : Bool = true ) : T
	{
		var mappingID = className | name;
		var mapping = cast this._mapping[ mappingID ];
		
		if ( mapping != null )
		{
			return mapping.getResult( targetType );
		}
		else if ( this._parentInjector != null )
		{
			return this._parentInjector.getInstanceWithClassName( className, name, targetType );
		}
		else if ( shouldThrowAnError )
		{
			var errorMessage = "Injector is missing a mapping to get instance with type '" + className + "'";
			errorMessage += ( targetType != null ) ? " in class '" + Type.getClassName( targetType ) + "'." : ".";
			errorMessage += " Target dependency: '" + mappingID + "'";
			throw new MissingMappingException( errorMessage );
		}
		
		return null;
	}
	
	public function getProvider<T>( className : ClassName, ?name : MappingName ) : IDependencyProvider<T>
	{
		var mappingID = className | name;
		var mapping = cast this._mapping[ mappingID ];

		if ( mapping != null )
		{
			return mapping.provider;
		}
		else if ( this._parentInjector != null )
		{
			return this._parentInjector.getInstanceWithClassName( className, name );
		}
		else
		{
			return null;
		}
	}

    public function instantiateUnmapped<T>( type : Class<T> ) : T
	{
		#if debug
		if ( type == null ) throw new NullPointerException( 'type cant be null' );
		#end
		
		var instance : Dynamic; 
		try
		{
			instance = ( cast type ).__ac( this.getInstanceWithClassName );
		}
		catch ( e : MissingMappingException )
		{
			throw( e );
		}
		catch( e : Dynamic )
		{
			instance = Type.createInstance( type, [] );
		}

		try
		{
			if ( instance.acceptInjector != null )
			{
				this._applyInjection( instance, type );
			}
		}
		catch ( e : MissingMappingException )
		{
			throw( e );
		}
		/*catch ( e : Dynamic )
		{
			//Do nothing
		}*/

		return instance;
	}

    public function getOrCreateNewInstance<T>( type : ClassRef<T> ) : T
	{
		return this.satisfies( type ) ? this.getInstance( type ) : this.instantiateUnmapped( type );
	}
	
	public function hasMapping<T>( type : ClassRef<T>, ?name : MappingName ) : Bool
	{
		var mappingID = this._getMappingID( type, name );
		
		if ( this._mapping[ mappingID ] != null )
		{
			return true;
		}
		else if ( this._parentInjector != null )
		{
			return this._parentInjector.hasMapping( type, name );
		}
		else
		{
			return false;
		}
	}
	
	public function unmap<T>( type : ClassRef<T>, ?name : MappingName ) : Void
	{
		this._unmap( this._getMappingID( type, name ) );
	}
	
	public function unmapClassName( className : ClassName, ?name : MappingName ) : Void
	{
		this._unmap( className | name );
	}
	
	public function hasDirectMapping( type : ClassRef<Dynamic>, ?name : MappingName ) : Bool
	{
		return this._mapping[ this._getMappingID( type, name ) ] != null;
	}

    public function satisfies( type : ClassRef<Dynamic>, ?name : MappingName ) : Bool
	{
		var mappingID = this._getMappingID( type, name );
		var mapping = cast this._mapping[ mappingID ];

		if ( mapping != null )
		{
			return mapping.provider != null;
		}
		else if ( this._parentInjector != null )
		{
			return this._parentInjector.satisfies( type, name );
		}
		else
		{
			return false;
		}
	}

	public function satisfiesDirectly( type : ClassRef<Dynamic>, ?name : MappingName ) : Bool
	{
		var mappingID = this._getMappingID( type, name );
		var mapping = cast this._mapping[ mappingID ];
		return ( mapping != null ) ? mapping.provider != null : false;
	}

    public function injectInto( target : IInjectorAcceptor ) : Void
	{
		this._applyInjection( target, Type.getClass( target ) );
	}

    public function destroyInstance( instance : Dynamic ) : Void
	{
		if ( this._managedObjects.containsKey( instance ) )
		{
			this._managedObjects.remove( instance );
			instance.__ap();
		}
	}

	public function map<T>( type : ClassRef<T>, ?name : MappingName ) : InjectionMapping<T>
	{
		var mappingID = this._getMappingID( type, name );

		if ( this._mapping[ mappingID ] != null )
		{
			return cast this._mapping[ mappingID ];
		}
		else
		{
			return this._createMapping( mappingID );
		}
	}

	public function teardown() : Void
	{
		for ( mapping in this._mapping )
		{
			mapping.provider.destroy();
		}

		var values = this._managedObjects.getValues();
		for ( value in values )
		{
			this.destroyInstance( value );
		}

		this._mapping 						= new Map();
		this._processedMapping 				= new Map();
		this._managedObjects 				= new ArrayMap<Dynamic, Dynamic>();
		
		#if !macro
		this.trigger.disconnectAll();
		#end
	}
	
	public function mapClassName<T>( className : ClassName, ?name : MappingName ) : InjectionMapping<T>
	{
		var mappingID = className | name;
		
		if ( this._mapping[ mappingID ] != null )
		{
			return cast this._mapping[ mappingID ];
		}
		else
		{
			return this._createMapping( mappingID );
		}
	}
	
	public function mapClassNameToValue<T>( className : ClassName, value : T, ?name : MappingName ) : Void
	{
		this.mapClassName( className, name ).toValue( value );
	}

    public function mapClassNameToType<T>( className : ClassName, type : Class<T>, ?name : MappingName ) : Void
	{
		this.mapClassName( className, name ).toType( type );
	}

    public function mapClassNameToSingleton<T>( className : ClassName, type : Class<T>, ?name : MappingName ) : Void
	{
		this.mapClassName( className, name ).toSingleton( type );
	}
	
	//
	inline function _unmap( mappingID : String ): Void
	{
		var mapping = this._mapping[ mappingID ];

		#if debug
		if ( mapping == null )
		{
			LogManager.getLoggerByInstance(this).warn( "Unmap failed with mapping named '" + mappingID + 
					"'. Maybe this mapping was overridden previously." );
		}
		#end

		if ( mapping != null )
		{
			mapping.provider.destroy();
			this._mapping.remove( mappingID );
		}
	}

	function _createMapping<T>( mappingID : String ) : InjectionMapping<T>
	{
		if ( this._processedMapping[ mappingID ] )
		{
			throw new InjectorException( "Mapping named '" + mappingID + "' is already processing" );
		}

		this._processedMapping[ mappingID ] = true;

		var mapping = new InjectionMapping( this, mappingID );
		this._mapping[ mappingID ] = mapping;
		this._processedMapping.remove( mappingID );

		return mapping;
	}
	
	function _applyInjection( target : IInjectorAcceptor, targetType : Class<Dynamic> ) : Void
	{
		#if !macro
		this.trigger.onPreConstruct( this, target, targetType );
		#end

		target.acceptInjector( this );
		
		try
		{
			if ( untyped target.__ap != null )
			{
				this._managedObjects.put( target,  target );
			}
		}
		catch ( e : Dynamic )
		{
			
		}
		
		#if !macro
		this.trigger.onPostConstruct( this, target, targetType );
		#end
	}
	
	//
	inline function _getMappingID( type : ClassName, name : MappingName ) : String
	{
		return type | name;
	}
}
