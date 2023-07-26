Feature: Open Portal 

    The open portal connects to a portal at one or more locations and opens it.

    Scenario: Open with admin rigths
        Given I am an admin
        When I open the portal
        Then I can merge the content with the content on DB and write it back to the store

    Scenario: Open without admin rigths
        Given I am not an admin
        When I open the portal
        Then I can only merge the content in memory

    Scenario: Conflicting permissions
        When I merge permissions and there are conflicts
        Then I can resolve them by filtering the invalid permissions

    Scenario: 