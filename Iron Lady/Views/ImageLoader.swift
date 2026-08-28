//
//  ImageLoader.swift
//  Iron Lady
//
//  Created by Dino Grillo on 1/22/26.
//
import UIKit

func loadImage(from fileName: String) -> UIImage? {
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
        .appendingPathComponent(fileName)

    guard let imageURL = url else { return nil }
    return UIImage(contentsOfFile: imageURL.path)
}

