import SwiftUI

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    let onSignIn: (String, String) -> Void

    var body: some View {
        Form {
            Section {
                TextField("LibreLinkUp email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("LibreLinkUp email")

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .accessibilityLabel("LibreLinkUp password")
            } header: {
                Text("Connect LibreLinkUp")
            } footer: {
                Text("Use the follower account connected in LibreLinkUp. The password is stored only in this iPhone’s Keychain.")
            }

            Section {
                Button("Connect") {
                    let submittedPassword = password
                    password = ""
                    onSignIn(email, submittedPassword)
                }
                .frame(maxWidth: .infinity)
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
            }

            Section {
                DisclaimerView()
            }
        }
        .navigationTitle("Libre Glucose")
    }
}
