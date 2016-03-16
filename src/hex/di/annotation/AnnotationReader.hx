package hex.di.annotation;

import haxe.Json;
import haxe.macro.Context;
import haxe.macro.Expr.Field;
import hex.di.annotation.InjectorArgumentVO;
import hex.di.annotation.InjectorClassVO;
import hex.di.annotation.InjectorMethodVO;
import hex.di.annotation.InjectorPropertyVO;
import hex.annotation.ClassAnnotationData;

/**
 * ...
 * @author Francis Bourre
 */
class AnnotationReader
{
	function new() 
	{
		
	}
	
	macro public static function readMetadata( metadataName : String ) : Array<Field>
	{
		var localClass = Context.getLocalClass().get();
		
		//parse annotations
		var fields : Array<Field> = hex.annotation.AnnotationReader.parseMetadata( metadataName, [ "Inject", "PostConstruct", "Optional", "PreDestroy" ], true );
		
		//get data result
		var data = hex.annotation.AnnotationReader._static_classes[ hex.annotation.AnnotationReader._static_classes.length - 1 ];
		
		//create Json
		var json = Json.stringify( AnnotationReader._adaptToSpeedInject( data ) );
		
		//add Json as metadata
		localClass.meta.add( metadataName, [ Context.parse( "'" + json + "'", localClass.pos ) ], localClass.pos );
		
		return fields;
	}
	
	private static function _adaptToSpeedInject( data : ClassAnnotationData ) : InjectorClassVO
	{
		var length : Int;

		//constructor parsing
		var ctorArgs : Array<InjectorArgumentVO> = [];
		
		var ctorAnn = data.constructorAnnotationData;
		if ( ctorAnn != null )
		{
			length = ctorAnn.argumentDatas.length;
			for ( i in 0...length )
			{
				var annotations = ctorAnn.annotationDatas;
				
				var inject = annotations.filter( function ( v ) { return v.annotationName == "Inject"; } );
				var key = inject.length > 0 ? inject[ 0 ].annotationKeys[ i ] : "";

				var optional = annotations.filter( function ( v ) { return v.annotationName == "Optional"; } );
				var isOpt = optional.length > 0 ? optional[ 0 ].annotationKeys[ i ] : false;
				
				ctorArgs.push( { type: ctorAnn.argumentDatas[ i ].argumentType, key: key==null?"":key, isOpt: isOpt==null?false:isOpt } );
			}
		}
		var ctor : InjectorMethodVO = { name: "new", args: ctorArgs, isPre: false, isPost: false, order: 0 };

		//properties parsing
		var props : Array<InjectorPropertyVO> = [];
		
		var propAnn = data.properties;
		length = propAnn.length;
		for ( i in 0...length )
		{
			var annotations = propAnn[ i ].annotationDatas;
			
			var inject = annotations.filter( function ( v ) { return v.annotationName == "Inject"; } );
			var key = inject.length > 0 ? inject[ 0 ].annotationKeys[ 0 ] : "";

			var optional = annotations.filter( function ( v ) { return v.annotationName == "Optional"; } );
			var isOpt = optional.length > 0 ? optional[ 0 ].annotationKeys[ 0 ] : false;
			
			props.push( { name: propAnn[ i ].propertyName, type: propAnn[ i ].propertyType, key: key==null?"":key, isOpt: isOpt==null?false:isOpt } );
		}

		//methods parsing
		var methods : Array<InjectorMethodVO> = [];
		
		var methAnn = data.methods;
		length = methAnn.length;
		for ( i in 0...length )
		{
			// arguments parsing
			var args : Array<InjectorArgumentVO> = [];
			
			var argData = methAnn[ i ].argumentDatas;
			var argLength = argData.length;
			for ( j in 0...argLength )
			{
				var annotations = methAnn[ i ].annotationDatas;
				
				var inject = annotations.filter( function ( v ) { return v.annotationName == "Inject"; } );
				var key = inject.length > 0 ? inject[ 0 ].annotationKeys[ j ] : "";
				
				var optional = annotations.filter( function ( v ) { return v.annotationName == "Optional"; } );
				var isOpt = optional.length > 0 ? optional[ 0 ].annotationKeys[ j ] : false;
				
				args.push( { type: argData[ j ].argumentType, key: key==null?"":key, isOpt: isOpt==null?false:isOpt } );
			}
			
			//method building
			var postConstruct = methAnn[ i ].annotationDatas.filter( function ( v ) { return v.annotationName == "PostConstruct"; } );
			var preDestroy = methAnn[ i ].annotationDatas.filter( function ( v ) { return v.annotationName == "PreDestroy"; } );
			var order = 0;
			if ( postConstruct.length > 0 ) order = postConstruct[ 0 ].annotationKeys[ 0 ];
			if ( preDestroy.length > 0 ) order = preDestroy[ 0 ].annotationKeys[ 0 ];
			methods.push( { name: methAnn[ i ].methodName, args: args, isPre: preDestroy.length>0, isPost: postConstruct.length>0, order: order==null?0:order } );
		}
	
		//final building
		//trace( data.name, { name:data.name, ctor:ctor, props:props, methods:methods } );
		return { name:data.name, ctor:ctor, props:props, methods:methods };
	}
}