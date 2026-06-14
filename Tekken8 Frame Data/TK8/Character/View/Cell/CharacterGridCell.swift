//
//  CharacterGridCell.swift
//  TK8
//

import Combine
import Foundation
import SwiftUI

struct CharacterGridCell: View, ReuseIdentifiable {
    var character: Character
    let characterImagePublisher: AnyPublisher<[String: UIImage], Never>
    @State var characterImages: [String: UIImage]

    private var localizedName: String {
        let preferredLanguage = Bundle.main.preferredLocalizations.first
        return preferredLanguage == "ko" ? character.nameKR : character.nameEN
    }

    var body: some View {
        GeometryReader { proxy in
            let imageLength = max(proxy.size.width - (Constants.Literals.cardPadding * 2), 0)

            VStack(spacing: 0) {
                characterImage
                    .frame(width: imageLength, height: imageLength)
                    .clipShape(.rect(cornerRadius: Constants.Literals.imageCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.Literals.imageCornerRadius)
                            .fill(.white.opacity(0.05))
                    )

                Text(localizedName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: Constants.Literals.nameAreaHeight)
                    .padding(.horizontal, 6)
            }
            .padding(Constants.Literals.cardPadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: Constants.Literals.cardCornerRadius)
                    .fill(.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Literals.cardCornerRadius)
                    .stroke(.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .onReceive(characterImagePublisher) { images in
            characterImages = images
        }
    }

    private var characterImage: some View {
        let img = characterImages[character.nameEN]

        return Image(uiImage: img ?? UIImage(named: "mokujin")!)
            .resizable()
            .scaledToFill()
    }
}

private enum Constants {
    enum Literals {
        static let cardPadding: CGFloat = 6
        static let cardCornerRadius: CGFloat = 12
        static let imageCornerRadius: CGFloat = 10
        static let nameAreaHeight: CGFloat = 40
    }
}

#Preview {
    CharacterGridCell(
        character: Character(
                    id: 1,
                    nameEN: "Nina",
                    nameKR: "니나 윌리엄스",
                    imageURL: "https://i.ibb.co/GXN7B5k/nina.png"
                ),
                characterImagePublisher: Empty().eraseToAnyPublisher(),
                characterImages: [:]
            )
            .frame(width: 120, height: 160)
            .background(Color(uiColor: .tkBackground)
    )
}
