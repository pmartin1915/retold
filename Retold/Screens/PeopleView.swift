import SwiftData
import SwiftUI

/// The People list (R7b section 7.5).
struct PeopleView: View {
    @Query(sort: \Person.name) private var people: [Person]

    var body: some View {
        List(people) { person in
            NavigationLink(person.name, destination: PersonView(person: person))
        }
        .navigationTitle(AppCopy.peopleHeader)
    }
}

/// One person's page: the person engine's open questions, then their episodes, newest first.
struct PersonView: View {
    let person: Person

    var body: some View {
        List {
            OfferSection(
                offers: QuestionEngine.queue(for: PersonState(person: person)),
                target: .person(person)
            )
            Section {
                ForEach(person.episodes.newestFirst()) { episode in
                    EpisodeRow(episode: episode)
                }
            }
        }
        .navigationTitle(person.name)
    }
}
