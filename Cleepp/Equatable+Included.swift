//
//  ContainsInverted.swift
//  Cleepp
//
//  Created by Pierre Houston on 2024-03-10.
//  Copyright © 2024 Bananameter Labs. All rights reserved.
//
//  Insired by https://forums.swift.org/t/iscontained-in-array-extension-of-equatable/20223/28
//  Exercise for the reader: define operators ∈ and ∉
//
//  Created primarily for excluded, which I wanted to use in an
//  expression like:
//  `let foos = things.compactMap({ $0.foo?.excluded(from: [a,b,c]) })`
//  I then went on to generalize to included(in:) and all the
//  variations below and found an even better way to write similar
//  expressions: `let x = y.excluding([u,v,w])`
//
//  Note, I had to add the subtle variant of these functions when
//  a,b,c are optionals of foo's type so that it wouldn't fail with
//  "Cannot convert value of type 'Foo?' to expected element type 'Foo'".
//  Before adding those variants I instead needed an expression like:
//  `compactMap({ $0.foo?.excludedFrom([a,b,c].compactMap({$0})) })`
//
//  I then added inverse of Range.contains(), which I thought was best
//  named like inside(range r:), outside(range r:)
//

public extension Equatable {
  func isIncluded<S: Sequence>(in s: S) -> Bool where S.Element == Self {
    s.contains(self)
  }
  func isIncluded<S: Sequence>(in s: S) -> Bool where S.Element == Self? {
    s.contains(self)
  }
  
  func isIncluded(in s: Self...) -> Bool {
    s.contains(self)
  }
  func isIncluded(in s: Self?...) -> Bool {
    s.contains(self)
  }
  
  func isExcluded<S: Sequence>(in s: S) -> Bool where S.Element == Self {
    !s.contains(self)
  }
  func isExcluded<S: Sequence>(in s: S) -> Bool where S.Element == Self? {
    !s.contains(self)
  }
  
  func isExcluded(in s: Self...) -> Bool {
    !s.contains(self)
  }
  func isExcluded(in s: Self?...) -> Bool {
    !s.contains(self)
  }
  
  func included<S: Sequence>(in s: S) -> Self? where S.Element == Self {
    s.contains(self) ? self : nil
  }
  func included<S: Sequence>(in s: S) -> Self? where S.Element == Self? {
    s.contains(self) ? self : nil
  }
  
  func included(in s: Self...) -> Self? {
    s.contains(self) ? self : nil
  }
  func included(in s: Self?...) -> Self? {
    s.contains(self) ? self : nil
  }
  
  func excluded<S: Sequence>(from s: S) -> Self? where S.Element == Self {
    s.contains(self) ? nil : self
  }
  func excluded<S: Sequence>(from s: S) -> Self? where S.Element == Self? {
    s.contains(self) ? nil : self
  }
  
  func excluded(from s: Self...) -> Self? {
    s.contains(self) ? nil : self
  }
  func excluded(from s: Self?...) -> Self? {
    s.contains(self) ? nil : self
  }
}

// oh, maybe these are just other names for intersection, subtract :shrug:
// maybe find another variation that better describes which is iterated over
// and which is more optimal to call contains on, self or the parameter

public extension Sequence where Element: Equatable {
  // `self.contains { s.contains($0) }` should be the same as
  // `s.contains { self.contains($0) }` but maybe the latter is preferable
  // if we think self is more likely to be a Set? Note that when the
  // parameter is from varargs it will never a Set
//  func includes<S: Sequence>(_ s: S) -> Bool where S.Element == Element {
//    s.contains { contains($0) }
//  }
//  func includes<S: Sequence>(_  s: S) -> Bool where S.Element == Element? {
//    s.contains {
//      guard let e = $0 else { return false }
//      return self.contains(e)
//    }
//  }
  
  func includes<S: Sequence>(_ s: S) -> Bool where S.Element == Element {
    contains { s.contains($0) }
  }
  func includes<S: Sequence>(_  s: S) -> Bool where S.Element == Element? {
    contains { s.contains($0) }
  }
  
  func includes(_ s: Element...) -> Bool {
    contains { s.contains($0) }
  }
  func includes(_ s: Element?...) -> Bool {
    contains { s.contains($0) }
  }
  
  func excludes<S: Sequence>(_ s: S) -> Bool where S.Element == Element {
    contains { !s.contains($0) }
  }
  func excludes<S: Sequence>(_ s: S) -> Bool where S.Element == Element? {
    contains { !s.contains($0) }
  }
  
  func excludes(_ s: Element...) -> Bool {
    contains { !s.contains($0) }
  }
  func excludes(_ s: Element?...) -> Bool {
    contains { !s.contains($0) }
  }
  
  func including<S: Sequence>(_ s: S) -> [Element] where S.Element == Element {
    filter { s.contains($0) }
  }
  func including<S: Sequence>(_  s: S) -> [Element] where S.Element == Element? {
    filter { s.contains($0) }
  }
  
  func including(_ s: Element...) -> [Element] {
    filter { s.contains($0) }
  }
  func including(_ s: Element?...) -> [Element] {
    filter { s.contains($0) }
  }
  
  func excluding<S: Sequence>(_ s: S) -> [Element] where S.Element == Element {
    filter { !s.contains($0) }
  }
  func excluding<S: Sequence>(_ s: S) -> [Element] where S.Element == Element? {
    filter { !s.contains($0) }
  }
  
  func excluding(_ s: Element...) -> [Element] {
    filter { !s.contains($0) }
  }
  func excluding(_ s: Element?...) -> [Element] {
    filter { !s.contains($0) }
  }
}

// maybe add this that always makes a set of the parameter Sequence beforehand?
//public extension Sequence where Element: Hashable {
  // repeat all above functions only with:
  //  let set = Set(s)
  //  filter { !set.contains($0) }
//}

public extension Comparable {
  func isInside(range r: Range<Self>) -> Bool {
    r.contains(self)
  }
  func isInside(range r: ClosedRange<Self>) -> Bool {
    r.contains(self)
  }
  
  func isOutside(range r: Range<Self>) -> Bool {
    !r.contains(self)
  }
  func isOutside(range r: ClosedRange<Self>) -> Bool {
    !r.contains(self)
  }
  
  func inside(range r: Range<Self>) -> Self? {
    r.contains(self) ? self : nil
  }
  func inside(range r: ClosedRange<Self>) -> Self? {
    r.contains(self) ? self : nil
  }
  
  func outside(range r: Range<Self>) -> Self? {
    r.contains(self) ? nil : self
  }
  func outside(range r: ClosedRange<Self>) -> Self? {
    r.contains(self) ? nil : self
  }
}

public extension Sequence where Element: Comparable {
  func thoseInside(range r: Range<Element>) -> [Element] {
    filter { r.contains($0) }
  }
  func thoseInside(range r: ClosedRange<Element>) -> [Element] {
    filter { r.contains($0) }
  }
  
  func thoseOutside(range r: Range<Element>) -> [Element] {
    filter { !r.contains($0) }
  }
  func thoseOutside(range r: ClosedRange<Element>) -> [Element] {
    filter { !r.contains($0) }
  }
}
