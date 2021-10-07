lint-fix:
	@swiftlint --fix --format Package.swift
	@swiftlint --fix --format Sources/
	@swiftlint --fix --format Tests/

precommit: lint-fix
	swift test --generate-linuxmain
	@swiftlint --fix --format Tests/

test: 
	swift test -c release --enable-code-coverage

buildRelease:
	swift build -c release

clean:
	swift package reset
	-rm -rdf .swiftpm/xcode
	-rm -rdf .build/
	-rm Package.resolved
	-rm .DS_Store

cleanArtifacts:
	swift package clean
