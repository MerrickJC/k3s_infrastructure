# Database Brainstorm

## Entities Being Mapped
Entities can be broken down into system entities and data storage entities.

### Data Storage Entities
- File stored in object storage
- Job run output
- Job run requests
- Analysis scripts stored in git

### System Entities
- Object storage
- Git repository
- Git issues integration

### Thoughts
It would be desirable to make everything easy to substitute. For example, changing the git repository that a script is stored in should not be a convoluted task. Similarly, storing bags in a different location should not be convoluted.


## Entity Breakdown
A closer inspection of the relevant fields for each entity

### Files
Files keep track of the central metadata for an object stored in the platform. While the "file" may initially be ROS bags (.mcap files) the system should remain extensible. Hence the term "files" is being used instead of bags.

| Field Name    | Description |
| datetime      | The date and time that the file was created |
| testing session (relation) | The testing session that the file was created at |
| type          | The type of the file |
| additional metadata | A JSON-structured field that contains whatever semi-structured data MMS wants to 


### Testing Session
Files recorded can be logically sorted together based on the testing session that they were recorded during. Testing sessions may have additional information recorded about them, such as location, personnel, environmental conditions, etc.

| Field Name            | Description |
| ---                   | --- |
| date                  | the date the testing session occured on |
| location (relation)   | the location that the testing session occurd at |
| personnel             | list of people, probably the ones in charge |
| 