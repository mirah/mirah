package org.foo;

public class ClassWithSelfReferencingTypeParameter<P extends ClassWithSelfReferencingTypeParameter<P>> {
	
	P self;
	
	@SuppressWarnings("unchecked")
	public ClassWithSelfReferencingTypeParameter() {
		this.self = (P) this;
	}
	
	public P foo() {
		return self;
	}
	
	public P bar() {
		return self;
	}
	
	public void baz() {
		System.out.println("baz");
	}
}

