## B+tree implementation in D

This is an in-memory implementation of the `B+Tree` Data structure in the `D` language.

### Initialization
The B+Tree object accepts takes `keys` and `values` of arbitrary types.

__API:__ `BPtree(K key, V value)`

```D
// The B+Tree module importation.
import bptree;

/**
 The structure of the B+Tree is in the form BPtree(K key, V value)
 where K and V are arbitrary types.
*/
// A tree with uint keys and string values with a degree of 2; the 
// minimum number of children a node can have.
auto tree = new BPtree!(uint, string)(2);

/**
  The minumn degree supported is 2, lower values will result in an InvalidArgumentException being thrown.
*/
auto tree2 = new BPtree!(uint, string)(1); // An exception is thrown.
```

### Adding entries to the tree
The `put` API is used to add entries to the tree.

__API:__ `put(K key, V value)`
```D
// Using the tree we defined above with uint keys and string values.
tree.put(0, "zero");
tree.put(1, "one");

// To update a key's value, use 'put' with the same key and a different value.
tree.put(0, "another zero"); // Updates the value associated with key = 0 to "another zero".
```

If the keys are an object type, a `class` for example, the class should implement/override `opEquals`, `to_hash` and `opCmp` methods. `==` and `<=`
are just some of the operations that the key is involved in.

### Retrieving values associated with the keys

#### Retrieve a value associated with a single key

__API:__ `get(K key)`
```D
// Get a value associated with `0`
auto value = tree.get(0); // Returns "another zero"

// When the key isn't present, a value is `Nullable.null`
value = tree.get(100); // Not in the tree, returns Nullable.null.
```

#### Retrieve values in a given key range.

__API:__ `get(K startKey, K endKey)`
```D
// Get a list of values, if pressent, that are associated with keys from the
// start key to the end key.
auto values = tree.get(0, 15); // Returns ["another zero", "one"]
// Keys [0, 1] are in the range 0...15 and their values are returned.

// If the specified key range does not cover the key-set then an empty array is returned
auto no_values = tree.get(3, 100); // Returns []
```

#### Retrieve values for each key in the passed key-set array.

__API:__ `get(K[] keys)`

This API expects the passed key array to contains keys __sorted in an increasing order__!

It returns an array of `values` equal to the length of the `keys` array pased.

```D
auto keyValues = tree.get([0, 1]); // Returns ["another zero", "one"]

/*
* For each key in the query array (K[] keys), a value is returned in the values array at the same index. If a key does not have an associated value, `Nullable.null` is returned in the values array at an index that is the same
as the key's index in the keys array.
*/
keyValues = tree.get([0, 1, 2, 3, 4]); // Returns ["another zero", "one", Nullable.null, Nullable.null, Nullable.null]
```

### Retrieve the entire set of keys present in the tree

__API:__ `keys()`

```D
auto keys = tree.keys; // Returns [0, 1] -> the keys currently present.
```

### Retrieve the entire array of values present in the tree

__API:__ `values()`

```D
auto values = tree.values; // Returns ["another zero", "one"]
```

### Retrieve a set of Entries present in the tree.

Entries have the following structure: `Entry(key, value, child)`. The entries returned by this method are the leaf node entries, where all `child` fields are set to __null__.

The `Entry` struct is exposed as a static member of the `BPtree` class.

__API:__ `entries`
```D
auto entries = tree.entries; // [Entry(0, "another zero", null), Entry(1, "one", null)]
```

### Check if a key exists in the tree

__API:__ `contains(K key)`
```D
auto containsOne = tree.contains(1); // Returns `true`

auot containsTwo = tree.contains(2); // Returns `false`
```

### Remove a key from the tree.

This not only removes the key with it's associated value from the tree, it also removes the key references from the internal index nodes of the tree.

Retur's `true` if the key to be removed as in the `B+Tree` with an associated value. `false` if the key wasn't in the tree.

__API:__ `remove(K key)`

```D
auto isRemoved = tree.remove(0); // Returns `true`
tree.get(0); // `Nullable.null`

isRemoved = tree.remove(10); // Returns `false`
```

### Clear the entire tree
Currently, all this does is et the tree's root node to point to a new node with the same `degree`. It doesn't remove the previous tree object from memory. The result is a new `clean` tree.

__API:__ `clear()`
```D
tree.get(1); // Returns 1.

tree.clear(); // Returns void.

tree.get(1); // `Nullable.null.`
```

### Get the tree's minimum degree

__API:__ `getMinimumDegree`

```
tree.getMinimumDegree // Returns `2`
```

### Get the size of the tree
Size here refers to the total number of entries in the leaf nodes. These are essentially entries with associated values.

__API:__ `getSize()`
```D
// Insert key, value pairs.
tree.put(1, "one");
tree.put(0, "zero");
tree.put(2, "two");
tree.put(3, "three");

tree.getSize // Return's 4.
```

### Get the height of the tree
The height is the number of edges from the `root` node to the `leaf` nodes.

__API:__ `getHeight`

```D
// Using the tree with entries above.

tree.getHeight // Returns 1.
```

### Get the string representation of the tree (for printing)

__API:__ `toString`

```D
tree.toString 
/**
Returns the following:

        3 three
        2 two
(2)
        1 one
        0 zero
*/
```

