//
//  Equatable+IsIn.swift
//  ClipStack
//
//  Created by Pierre Houston on 2024-03-10.
//  Copyright © 2024 p0deje. All rights reserved.
//

public extension Equatable {
  func isIn<S: Sequence>(_ s: S) -> Bool where S.Element == Self {
    return s.contains(self)
  }
  func isNotIn<S: Sequence>(_ s: S) -> Bool where S.Element == Self {
    return !s.contains(self)
  }
  func onlyIfIn<S: Sequence>(_ s: S) -> Self? where S.Element == Self {
    return s.contains(self) ? self : nil
  }
  func onlyIfNotIn<S: Sequence>(_ s: S) -> Self? where S.Element == Self {
    return s.contains(self) ? nil : self
  }
  func isIn(_ s: Self...) -> Bool {
    return s.contains(self)
  }
  func isNotIn(_ s: Self...) -> Bool {
    return !s.contains(self)
  }
  func onlyIfIn(_ s: Self...) -> Self? {
    return s.contains(self) ? self : nil
  }
  func onlyIfNotIn(_ s: Self...) -> Self? {
    return s.contains(self) ? nil : self
  }
}
