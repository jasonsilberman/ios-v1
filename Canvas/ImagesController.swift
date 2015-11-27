//
//  ImagesController.swift
//  Canvas
//
//  Created by Sam Soffes on 11/25/15.
//  Copyright © 2015 Canvas Labs, Inc. All rights reserved.
//

import UIKit
import CanvasText

class ImagesController {

	// MARK: - Types

	typealias Completion = (node: Image, image: UIImage?) -> Void


	// MARK: - Properties

	let session: NSURLSession

	private var downloading = [Image: [Completion]]()

	private let queue = dispatch_queue_create("com.usecanvas.canvas.imagescontroller", DISPATCH_QUEUE_SERIAL)

	/// The image ID is the key. The value is a UIImage object.
	private let cache: NSCache = {
		let cache = NSCache()
		cache.name = "ImagesController.cache"
		return cache
	}()

	static let sharedController = ImagesController()


	// MARK: - Initializers

	init(session: NSURLSession = NSURLSession.sharedSession()) {
		self.session = session
	}


	// MARK: - Accessing

	func fetchImage(node node: Image, size: CGSize, completion: Completion) -> UIImage? {
		if let image = cache[node.ID] as? UIImage {
			return image
		}

		coordinate {
			// Already downloading
			if var array = self.downloading[node] {
				array.append(completion)
				self.downloading[node] = array
				return
			}

			// Start download
			self.downloading[node] = [completion]

			let request = NSURLRequest(URL: node.URL)
			self.session.downloadTaskWithRequest(request) { [weak self] location, _, _ in
				self?.loadImage(location: location, node: node)
			}.resume()
		}

		return placeholderImage(size: size)
	}


	// MARK: - Private

	private func coordinate(block: dispatch_block_t) {
		dispatch_sync(queue, block)
	}

	private func loadImage(location location: NSURL?, node: Image) {
		let data = location.flatMap { NSData(contentsOfURL: $0) }
		let image = data.flatMap { UIImage(data: $0) }

		cache[node.ID] = image

		coordinate {
			if let completions = self.downloading[node] {
				for completion in completions {
					dispatch_async(dispatch_get_main_queue()) {
						completion(node: node, image: image)
					}
				}
				self.downloading[node] = nil
			}
			return
		}
	}

	private func placeholderImage(size size: CGSize, scale: CGFloat? = 0) -> UIImage? {
		guard let icon = UIImage(named: "ImagePlaceholder") else { return nil }

		let rect = CGRect(origin: .zero, size: size)

		UIGraphicsBeginImageContextWithOptions(size, true, scale ?? 0)

		// Background
		UIColor(red: 0.957, green: 0.976, blue: 1, alpha: 1).setFill()
		UIBezierPath(rect: rect).fill()

		// Icon
		UIColor(red: 0.729, green: 0.773, blue: 0.835, alpha: 1).setFill()
		let iconFrame = CGRect(
			x: (size.width - icon.size.width) / 2,
			y: (size.height - icon.size.height) / 2,
			width: icon.size.width,
			height: icon.size.height
		)
		icon.drawInRect(iconFrame)

		let image = UIGraphicsGetImageFromCurrentImageContext()

		UIGraphicsEndImageContext()

		return image
	}
}