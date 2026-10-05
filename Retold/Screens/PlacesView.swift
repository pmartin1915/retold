import SwiftData
import SwiftUI

/// The Places list (R7b section 7.5).
struct PlacesView: View {
    @Query(sort: \Place.name) private var places: [Place]

    var body: some View {
        List(places) { place in
            NavigationLink(place.name, destination: PlaceView(place: place))
        }
        .navigationTitle(AppCopy.placesTitle)
    }
}

/// One place's page: its episodes, newest first. There is no place engine, so no questions.
struct PlaceView: View {
    let place: Place

    var body: some View {
        List {
            Section {
                ForEach(place.episodes.newestFirst()) { episode in
                    EpisodeRow(episode: episode)
                }
            }
        }
        .navigationTitle(place.name)
    }
}
