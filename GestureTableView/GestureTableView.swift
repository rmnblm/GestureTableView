// MIT License
//
// Copyright (c) 2017 Roman Blum
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

public class GestureTableView: UITableView {
  public var canReorder = true {
    didSet {
      longPressGestureRecognizer.isEnabled = canReorder
    }
  }

  public var minimumPressDuration: CFTimeInterval {
    get { return longPressGestureRecognizer.minimumPressDuration }
    set { longPressGestureRecognizer.minimumPressDuration = newValue }
  }

  public var draggingViewOpacity: Float = 1.0
  public var draggingRowHeight: CGFloat = 50.0
  public var draggingZoomScale: CGFloat = 1.1
  public var scrollRate: CGFloat = 0.0

  private var longPressGestureRecognizer: UILongPressGestureRecognizer!
  private var currentLocationIndexPath: IndexPath?
  private var initialIndexPath: IndexPath?
  private var draggingView: UIImageView?
  private var scrollDisplayLink: CADisplayLink?

  private func commonInit() {
    longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
    addGestureRecognizer(longPressGestureRecognizer)
  }

  public override init(frame: CGRect, style: UITableViewStyle) {
    super.init(frame: frame, style: style)
    commonInit()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }

  public func longPressed(_ recognizer: UILongPressGestureRecognizer) {
    let location = recognizer.location(in: self)
    let indexPath = indexPathForRow(at: location)

    var rows = 0
    for index in 0..<numberOfSections {
      rows += numberOfRows(inSection: index)
    }

    if rows == 0 || (recognizer.state == .began && indexPath == nil) ||
      (recognizer.state == .ended && currentLocationIndexPath == nil) ||
      (recognizer.state == .began && indexPath != nil
        && !(dataSource?.tableView?(self, canMoveRowAt: indexPath!) ?? true)) {
      cancelGesture()
      return
    }

    if recognizer.state == .began {
      longPressBegan(indexPath: indexPath, location: location)
    } else if recognizer.state == .changed {
      longPressChanged(location: location)
    } else if recognizer.state == .ended {
      longPressEnded()
    }
  }

  private func longPressBegan(indexPath: IndexPath?, location: CGPoint) {
    guard let indexPath = indexPath, let cell = cellForRow(at: indexPath) else {
      return
    }

    draggingRowHeight = cell.frame.size.height
    cell.isSelected = false
    cell.isHighlighted = false

    UIGraphicsBeginImageContextWithOptions(cell.bounds.size, false, 0)
    cell.layer.render(in: UIGraphicsGetCurrentContext()!)
    let cellImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    if draggingView == nil {
      draggingView = UIImageView(image: cellImage)
      addSubview(draggingView!)
      let rect = rectForRow(at: indexPath)
      draggingView!.frame = draggingView!.bounds.offsetBy(dx: rect.origin.x, dy: rect.origin.y)

      draggingView!.layer.masksToBounds = false
      draggingView!.layer.shadowColor = UIColor.black.cgColor
      draggingView!.layer.shadowOffset = .zero
      draggingView!.layer.shadowRadius = 4.0
      draggingView!.layer.shadowOpacity = 0.7
      draggingView!.layer.opacity = draggingViewOpacity

      UIView.beginAnimations("zoom", context: nil)
      draggingView!.transform = CGAffineTransform(scaleX: draggingZoomScale, y: draggingZoomScale)
      draggingView!.center = CGPoint(x: center.x, y: location.y)
      UIView.commitAnimations()
    }

    cell.isHidden = true
    currentLocationIndexPath = indexPath
    initialIndexPath = indexPath

    scrollDisplayLink = CADisplayLink(target: self, selector: #selector(scrollTableWithCell))
    scrollDisplayLink!.add(to: RunLoop.main, forMode: .defaultRunLoopMode)
  }

  private func longPressChanged(location: CGPoint) {
    if location.y >= 0 && location.y <= contentSize.height + 50 {
      draggingView?.center = CGPoint(x: center.x, y: location.y)
    }

    var rect = bounds
    rect.size.height -= contentInset.top

    updateCurrentLocation()

    let scrollZoneHeight = rect.size.height / 6
    let bottomScrollBeginning = contentOffset.y + contentInset.top + rect.size.height - scrollZoneHeight
    let topScrollBeginning = contentOffset.y + contentInset.top + scrollZoneHeight

    if location.y >= bottomScrollBeginning {
      scrollRate = (location.y - bottomScrollBeginning) / scrollZoneHeight
    } else if location.y <= topScrollBeginning {
      scrollRate = (location.y - topScrollBeginning) / scrollZoneHeight
    } else {
      scrollRate = 0
    }
  }

  private func longPressEnded() {
    scrollDisplayLink?.invalidate()
    scrollDisplayLink = nil
    scrollRate = 0

    guard let indexPath = currentLocationIndexPath,
      let cell = cellForRow(at: indexPath),
      let draggingView = self.draggingView else {
        return
    }

    UIView.animate(withDuration: 0.3, animations: {
      let rect = self.rectForRow(at: indexPath)
      draggingView.transform = CGAffineTransform.identity
      draggingView.frame = draggingView.bounds.offsetBy(dx: rect.origin.x, dy: rect.origin.y)
    }, completion: { _ in
      draggingView.removeFromSuperview()
      cell.isHidden = false
      self.dataSource?.tableView?(self, moveRowAt: self.initialIndexPath!, to: indexPath)
      if let visibleRows = self.indexPathsForVisibleRows?.filter({ $0 != indexPath }) {
        self.reloadRows(at: visibleRows, with: .none)
      }

      self.currentLocationIndexPath = nil
      self.initialIndexPath = nil
      self.draggingView = nil
    })
  }

  public func updateCurrentLocation() {
    let location = longPressGestureRecognizer.location(in: self)
    guard let currentLocationIndexPath = self.currentLocationIndexPath,
      var indexPath = indexPathForRow(at: location) else {
        return
    }

    if let initialIndexPath = self.initialIndexPath,
      let proposedIndexPath = delegate?.tableView?(
        self, targetIndexPathForMoveFromRowAt: initialIndexPath, toProposedIndexPath: indexPath) {
      indexPath = proposedIndexPath
    }

    let oldHeight = rectForRow(at: currentLocationIndexPath).size.height
    let newHeight = rectForRow(at: indexPath).size.height

    if indexPath != currentLocationIndexPath &&
      longPressGestureRecognizer.location(in: cellForRow(at: indexPath)).y > newHeight - oldHeight {
      beginUpdates()
      moveRow(at: currentLocationIndexPath, to: indexPath)
      self.currentLocationIndexPath = indexPath
      endUpdates()
    }
  }

  public func scrollTableWithCell(_ timer: Timer) {
    let location = longPressGestureRecognizer.location(in: self)
    let currentOffset = contentOffset
    var newOffset = CGPoint(x: currentOffset.x, y: currentOffset.y + scrollRate * 10)

    if newOffset.y < -contentInset.top {
      newOffset.y = -contentInset.top
    } else if contentSize.height + contentInset.bottom < frame.size.height {
      newOffset = currentOffset
    } else if newOffset.y > (contentSize.height + contentInset.bottom) - frame.size.height {
      newOffset.y = (contentSize.height + contentInset.bottom) - frame.size.height
    }

    contentOffset = newOffset

    if location.y >= 0 && location.y <= contentSize.height + 50 {
      draggingView?.center = CGPoint(x: center.x, y: location.y)
    }

    updateCurrentLocation()
  }

  private func cancelGesture() {
    longPressGestureRecognizer.isEnabled = false
    longPressGestureRecognizer.isEnabled = true
  }
}
