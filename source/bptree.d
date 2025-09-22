/**
 * Author: ochibobowarren
 *
 * In-Memory implementation of a b+tree in D language.
 *
 * Child Nodes will have neighbouring links.
 */
module bptree;

import std.stdio : writeln;
import std.string : format, empty;
import std.typecons : Nullable;

class BPtree(K, V)
{
    // The minimum degree of a `BPtree` node
    // This means that each node must have at least a `degree - 1` number of nodes
    // else its entries should be merged with neighbouring nodes.
    // The maximum number of entries in a node is `(2*degree - 1)`
    private uint degree;

    // The maximum degree of a node.
    // It is (2 * degree - 1).
    private uint maxDegree;

    // The height of the BPtree
    // It only increases during splits.
    private uint height;

    // The size of the BPtree
    // This refers to the total number of entries in all leaf nodes
    private uint size;

    // The root node of the tree.
    private Node* root;

    // The size of the entries array in each node
    private uint ENTRIES_SIZE;

    /**
        The structure of a node Entry.

        A node `entry` holds contains data of the BPtree.
    */
    private static struct Entry
    {
        K key;
        V value;
        private Node* child;

        // For creating an instance of an entry in an internal node
        // Internal nodes have no `value`, `previous` or `next` fields.
        this(K key, Node* child)
        {
            this.key = key;
            this.child = child;
        }

        this(K key, V value)
        {
            this.key = key;
            this.value = value;
        }

        void setChildNode(Node* childNode)
        {
            this.child = childNode;
        }

        Node* getChild()
        {
            return this.child;
        }

        void setKey(K newKey)
        {
            this.key = newKey;
        }

        void setValue(V newValue)
        {
            this.value = newValue;
        }
    }

    // An alias for a vector of entries
    alias Entries = Entry[];

    /**
        The structure of a node in the BPtree.
    */
    private static struct Node
    {
        uint n; // Number of child nodes
        uint capacity; // Maximum number of entries the node can hold.
        uint minimumNumberOfNodeEntries;
        Entries entries;

        // Useful for `leaf nodes` only.
        private Node* next;
        private Node* previous;

        this(uint m, uint max_size)
        {
            this.n = m;
            this.capacity = max_size;
            this.entries = new Entry[max_size];
            // Degree less 1.
            this.minimumNumberOfNodeEntries = (max_size / 2) - 1;
        }

        void setPreviousNode(Node* prevNode)
        {
            this.previous = prevNode;
        }

        void setNextNode(Node* nextNode)
        {
            this.next = nextNode;
        }

        Node* getPreviousNode()
        {
            return this.previous;
        }

        Node* getNextNode()
        {
            return this.next;
        }

        bool insertAt(uint index, Entry entry)
        {
            if (index >= this.capacity || index < 0)
            {
                return false;
            }

            // Shift entries to make space for the new child
            for (uint i = this.n; i > index; i--)
                this.entries[i] = this.entries[i - 1];

            // Insert the new child at the specified index
            this.entries[index] = entry;
            this.n += 1;
            return true;
        }

        // TODO: add a boolean for destroying the child optionally.
        bool removeAt(uint index)
        {
            if (index >= this.capacity || index < 0)
                return false;

            // TODO: Should we destroy the child at this index at this point?
            // Set the child pointer to null
            this.entries[index].child = null;

            // Shift entries to fill the gap
            for (uint i = index; i < (this.n - 1); i++)
            {
                this.entries[i] = this.entries[i + 1];
            }
            // Decrement the number of entries
            this.n -= 1;
            return true;
        }

        // @Deprecated
        deprecated("Replaced by canBeBorrowedFrom") bool canBorrowFromPredecessor()
        {
            return false;
            // return this.previous != null && this.previous.n > getMinimumNumberOfEntries();
        }

        // @Deprecated
        deprecated("Replaced by canBeBorrowedFrom") bool canBorrowFromSuccessor()
        {
            return false;
            // return this.next != null && this.next.n > getMinimumNumberOfEntries();
        }

        // Check if this node can be borrowed from
        bool canBeBorrowedFrom(uint h)
        {
            if (h == 0)
                return this.n > this.minimumNumberOfNodeEntries;
            else
                return this.n > this.minimumNumberOfNodeEntries + 1;
        }

        // Get the child at a particular index
        Node* childAt(uint index)
        {
            if (index >= this.n || index < 0)
                return null;

            return this.entries[index].child;
        }

        // Get the child at the particular index and return it.
        // Remove the value at that index.
        Node* offerChildAt(uint index)
        {
            if (index >= this.n || index < 0)
                return null;

            Node* child = this.childAt(index);
            // Remove the child at this index and perform the necessary entries shifting
            this.removeAt(index);
            return child;
        }

        Nullable!Entry offerEntryAt(uint index)
        {
            auto entry = Nullable!Entry.init;
            if (index >= this.n || index < 0)
                return entry;

            entry = Nullable!Entry(entries[index]);
            // Remove the entry at this index and perform the necessary entries shifting
            this.removeAt(index);
            return entry;
        }

        // Get the global minimum value of the suBPtree at this node.
        K min()
        {
            return this.min(&this);
        }

        // Helper function to get the global minimum of the suBPtree at this node.
        private K min(Node* node)
        {
            // Leaf node
            if (node.childAt(0) == null)
                return node.entries[0].key;

            return min(node.childAt(0));
        }

        // Get the global maximum value of the suBPtree at this node.
        K max()
        {
            return this.max(&this);
        }

        // Helper function to get the global maximum of the suBPtree at this node.
        private K max(Node* node)
        {
            // Leaf node
            if (node.childAt(node.n - 1) == null)
                return node.entries[node.n - 1].key;

            return max(node.childAt(node.n - 1));
        }

        // Update the set key of the node at the given index.
        // Used to update index nodes usually after a borrow operation during deletion.
        void setNodeKeyAt(uint index, K key)
        {
            if (index >= this.n || index < 0)
                throw new Exception(
                    format(
                        "Invalid index argument (%s). The index must be between 0 and %s.", index, this
                        .n));

            this.entries[index].setKey(key);
        }

        // Get the key of the node entry at the given index.
        K keyAt(uint index)
        {
            if (index >= this.n || index < 0)
                throw new Exception(
                    format(
                        "Invalid index argument (%s). The index must be between 0 and %s.", index, this
                        .n));

            return this.entries[index].key;
        }

        // Extend node entries
        void extendWithNode(Node* srcNode)
        {
            for (uint i = 0; i < srcNode.n; i++)
            {
                this.entries[n++] = srcNode.entries[i];
            }

            this.next = srcNode.next;
            srcNode.previous = null;
        }
    }

    /**
     * Root Node, Inner Nodes, Child Nodes.
     * Root & Inner nodes have the same structure
     * Node structures
     * For internal nodes, we maintain the following invariant:
     * if len(children) == 0, len(items) is unconstrained
     * else len(children) == len(items) + 1
     */
    this(uint k)
    {
        k < 2 && throw new InvalidArgumentException(
            format(
                "Invalid BPtree degree argument (%s). The minimum degree must be > 2.", k));
        this.degree = k;
        this.ENTRIES_SIZE = this.degree * 2;
        this.maxDegree = this.ENTRIES_SIZE - 1;
        this.root = new Node(0, this.ENTRIES_SIZE);
    }

    /**
     *
     * Params:
     *   n = the initial number of entries that have values in a node.
     *
     */
    private Node* createNode(int n)
    {
        return new Node(n, this.ENTRIES_SIZE);
    }

    uint getMinimumDegree()
    {
        return degree;
    }

    private uint getMinimumNumberOfEntries()
    {
        return degree - 1;
    }

    uint getHeight()
    {
        return height;
    }

    uint getSize()
    {
        return this.size;
    }

    /**
        Add an element to the BPtree.

        Params:
            key = the key of type `K` to be inserted.
            value = the value of type `V` to be associated to the key.

        Returns:
            void

        Example:
        ----
        // Assuming the BPtree has minimum degree = 3
        auto BPtree = BPtree!(uint, string)(3);
        BPtree.put(8, "Hello");
        ----

        See:
            split
    */
    public void put(K key, V value)
    {
        auto nullableNode = this.insert(this.root, key, value, this.height);

        if (nullableNode.isNull)
            return;
        auto node = nullableNode.get;

        // Split the root into 2.
        auto newRoot = this.createNode(2);
        newRoot.entries[0] = Entry(this.root.entries[0].key, this.root);
        newRoot.entries[1] = Entry(node.entries[0].key, node);
        this.root = newRoot;

        // The split results in the tree growing.
        // Increase the height of the tree accordingly
        this.height++;
    }

    /**
     *
        The Algorithm:
            - If the node has no child.
            - If the node has multiple entries.

        Params:
            node = the node we want to insert in/from.
            key = the key we would like to insert
            value = the value associated with the key we would like to insert
            h = the current height of node `node` in the BPtree
        Returns:
            The node with our inserted Key & Value.
     */
    private Nullable!(Node*) insert(Node* node, K key, V value, uint h)
    {
        // Create a new entry instance.
        Entry entry;
        int i;

        // Inserts on leaf nodes.
        if (h == 0)
        {
            /* TODO: replace this with binary search that returns
                    the index of insert. The index is either an index where
                    the key is already existing, leading to replacement or
                    the index where the key would be inserted, if it is missing.
                    This improves the algorithm from O(n) to O(log(n)).
                    The entries are already sorted hence no need to sort again.
            */
            // Only get the index for insert at the leaf node.
            for (i = 0; i < node.n; i++)
            {
                // Equal sign added to replace the existing node.
                if (key <= node.entries[i].key)
                {
                    break;
                }
            }
            // Set the entry to be inserted as a leaf entry.
            entry = Entry(key, value);
        }
        // Use internal nodes for directions on where to insert.
        else
        {
            for (i = 0; i < node.n; i++)
            {
                if ((i + 1 == node.n) || key < node.entries[i + 1].key)
                {
                    auto nullableU = this.insert(node.entries[i++].child, key, value, h - 1);
                    if (nullableU.isNull)
                        return Nullable!(Node*).init;
                    auto u = nullableU.get;
                    //entry.key = u.entries[0].key;
                    entry = Entry(u.entries[0].key, u);
                    /**
                        Would have set the value to a null equivalent but that would require out
                        passed value to be a Nullable or internally wrapped in a Nullable.
                        The value for internal nodes is not used though, so there's no need to make it the right one.
                        Some internal nodes have mismatched values that are equal to their leaf children.
                        This can always be resolved but has no effect on the b+tree operations.
                        entry.value = null || NullOf(typeof(value));
                        This might be a way to optimize storage (internal nodes have null values (or null pointers))
                    */
                    break;
                }
            }

        }

        // Move the entries to the right, if necessary (when the key is to be inserted
        // at an index < n; a lower value key or at an index = n; higher value key for the set
        // of existing entries)
        // Conditionally moving nodes and increasing the node count only on inserts.
        // On updates, do not shift nodes or increase the number of entries.
        // A key-match indicates an update and there's no need to execute the logic in this if-block.
        // Given that the Entries array is initialized with values = Entry.init, if the key being inserted
        // is equal to the default key value in the entry, and this is the first key to be inserted into the
        // B+tree (when is the size is 0), then, the size of the tree (& node) should be updated accordingly.
        if (node.entries[i].key != key || this.size == 0)
        {
            for (int j = node.n; j > i; j--)
            {
                node.entries[j] = node.entries[j - 1];
            }
            // Increase the number of entries in the current node
            node.n++;
            // The number of leaf nodes (size) only increases on inserts, not updates.
            // This only happens when the insert is on the leaf node (h == 0)
            h == 0 && this.size++;
        }

        node.entries[i] = entry;

        // Split if the maxDegree is reached.
        if (node.n <= this.maxDegree)
            return Nullable!(Node*).init;
        return Nullable!(Node*)(this.split(node));
    }

    /**
        Splits the node of a BPtree

        Params:
            node = the node that is to be split.

        Returns:
            A new `node` that
    */
    private Node* split(Node* node)
    {
        auto u = this.createNode(this.degree);
        for (int i = 0; i < this.degree; i++)
        {
            u.entries[i] = node.entries[i + this.degree];
            node.entries[i + this.degree] = Entry.init; // This isn't necessary.
        }

        // Set the number of nodes in the `split` node to minDegree
        node.n = this.degree;

        // Update the node pointers.
        if (node.next != null)
        {
            node.next.previous = u;
        }
        u.next = node.next;
        node.setNextNode(u);
        u.setPreviousNode(node);

        return u;
    }

    /**
        Retrieves the value associated with the key, if the key is present in the BPtree. Return null otherwise.

        Params:
            key = the key whose value we are searching for
        Returns:
            The value associated with the key, if the key is present. If the key is absent, return null.

    */
    public Nullable!V get(K key)
    {
        return this.search(this.root, key, this.height);
    }

    /**
        Retrieves an array of values associated with the keys starting from the startKey to the endKey.
        It is expected that the `startKey` <= `endKey`. If this is not the case, an exception is thrown.

        If the `startKey` is not present in the node, we try to find the smallest key in the BPtree whose value
        is greater than the `startKey` and start from there. If no such key is present, it follows that an empty
        array is returned. If the `endKey` is not present in the tree, we collect values (provided that the `startKey`
        condition above is met) through all nodes until we get to the final node (whose last value is expected to be
        < `endKey`.)

        Params:
            startKey = the lower bound key that we start our search from.
            endKey = the upper bound key that we stop our search at.
        Returns:
            An array value associated with the keys from the `startKey` to the `endKey`.
    */
    public V[] get(K startKey, K endKey)
    {
        if (endKey < startKey)
            throw(
                new InvalidArgumentException(format(
                    "The startKey cannot be greater than the endKey. Received startKey=(%s) and endKey=(%s)", startKey,
                    endKey)));
        return this.search(this.root, startKey, endKey, this.height);
    }

    /**
        Retrieves an array of values associated with the key, For each key, if the key is present in the BPtree, then
        its associated value is appended to the array at the same index the key is in the passed array of keys. If a key
        is absent, a null value is set in the returned values array at the same index where the key is in the passed keys array.
        The array of keys is assumed to be sorted in non-decreasing order.

        Params:
            keys = the array of the keys whose values we are searching for
        Returns:
            The values array associated with the keys array where value of each key is set in the values array at the same index
            of the key in the keys array,
    */
    public Nullable!V[] get(K[] keys)
    {
        if (keys.length == 0)
            return (Nullable!V[]).init;

        return this.search(this.root, keys, this.height);
    }

    private Nullable!V search(Node* node, K key, uint height
    )
    {
        // Return a value only when at the root node
        if (height == 0)
        {
            // Search current node entries.
            // A binary search would suffice here as node entries are already sorted.
            auto index = BPtree.findIndexOf(node.entries, key, node.n);

            if (index < 0)
                return Nullable!V.init;

            return Nullable!V(node.entries[index].value);
        }

        // Use intenal nodes to guide search
        auto i = 0;
        for (i = 0; i < node.n; i++)
        {
            if (i + 1 < node.n)
            {
                if (key < node.entries[i + 1].key)
                {
                    break;
                }
            }
            else
            {
                break;
            }
        }

        return this.search(node.entries[i].child, key, height - 1);
    }

    // Search implementation to collect values between 2 keys (startKey, endKey)
    private V[] search(Node* node, K startKey, K endKey, uint height)
    {
        if (height == 0)
        {
            auto startKeyIndex = this.findIndexOf(node.entries, startKey, node.n, BinarySearchStrategy
                    .INSERTION_POSITION);
            if (startKeyIndex < 0)
            {
                return new V[0];
            }
            // Collect all values from startKey...endKey
            auto currentNode = node;
            V[] values = [];
            auto stop = false;
            while (currentNode != null)
            {
                for (auto i = startKeyIndex; i < currentNode.n; i++)
                {
                    if (currentNode.entries[i].key <= endKey)
                    {
                        values ~= currentNode.entries[i].value;
                    }
                    else
                    {
                        stop = true;
                    }
                }

                if (stop)
                    break;

                // Keep exploring entries the next node.
                currentNode = currentNode.next;
                // Re-initialize the startIndex to 0.
                startKeyIndex = 0;
            }

            return values;
        }

        auto i = 0;
        for (i = 0; i < node.n; i++)
        {
            if (i + 1 < node.n)
            {
                if (startKey < node.entries[i + 1].key)
                {
                    break;
                }
            }
            else
            {
                break;
            }
        }

        return this.search(node.entries[i].child, startKey, endKey, height - 1);
    }

    // Search implementation to collect all values based on the Key array
    private Nullable!V[] search(Node* node, K[] keys, uint height)
    {
        if (height == 0)
        {
            auto keyIndex = this.findIndexOf(node.entries, keys[0], node.n, BinarySearchStrategy
                    .INSERTION_POSITION);

            // Values related to each key in the passed keyset
            auto values = new Nullable!V[keys.length];
            auto currentNode = node;
            auto currentKeyIndex = 0;

            while (currentNode != null)
            {
                for (auto i = keyIndex; i < currentNode.n; i++)
                {
                    if (keys[currentKeyIndex] < currentNode.entries[i].key)
                    {
                        currentKeyIndex += 1;

                        if (currentKeyIndex == keys.length)
                            return values;
                    }

                    if (keys[currentKeyIndex] == currentNode.entries[i].key)
                    {
                        values[currentKeyIndex] = Nullable!V(currentNode.entries[i].value);
                        currentKeyIndex += 1;

                        if (currentKeyIndex == keys.length)
                            return values;
                    }
                }

                keyIndex = 0;
                currentNode = currentNode.next;
            }

            return values;
        }

        // Use intenal nodes to guide search
        auto i = 0;
        for (i = 0; i < node.n; i++)
        {
            if (i + 1 < node.n)
            {
                if (keys[0] < node.entries[i + 1].key)
                {
                    break;
                }
            }
            else
            {
                break;
            }
        }

        return this.search(node.entries[i].child, keys, height - 1);
    }

    /**
        Check if a key is present in the tree.

        Params:
            key= the key whose existence is being checked

        Returns:
            true, if the key is present, false otherwise.
     */
    public bool contains(K key)
    {
        return !search(this.root, key, this.height).isNull;
    }

    /**
        Retrieve the entire set of keys present in the `BPtree`

        Returns:
            set of keys present in the tree
     */
    public K[] keys()
    {
        if (this.root.entries.length == 0)
        {
            return new K[0];
        }

        return keys(this.root, this.height);
    }

    // Helper method to retrieve all keys in the tree.
    private K[] keys(Node* node, uint height)
    {
        if (height == 0)
        {
            K[] keys = [];
            auto currentNode = node;

            while (currentNode != null)
            {
                for (int i = 0; i < currentNode.n; i++)
                {
                    keys ~= currentNode.entries[i].key;
                }

                currentNode = currentNode.next;
            }

            return keys;
        }

        return keys(node.entries[0].child, height - 1);
    }

    /**
        Retrieve the entire array of values present in the `BPtree`

        Returns:
            array of values present in the tree
     */
    public V[] values()
    {
        if (this.root.entries.length == 0)
            return new V[0];

        return values(this.root, this.height);
    }

    // Helper method used to retreive all values present in the tree
    private V[] values(Node* node, uint height)
    {
        if (height == 0)
        {
            V[] values = [];
            auto currentNode = node;

            while (currentNode != null)
            {
                for (int i = 0; i < currentNode.n; i++)
                {
                    values ~= currentNode.entries[i].value;
                }

                currentNode = currentNode.next;
            }

            return values;
        }

        return values(node.entries[0].child, height - 1);
    }

    /**
        Retrieve the `Entries` in the `BPtree`. An `Entry` is simply a `key-value` pair.

        Returns
            array of entries present in the tree
     */
    public Entries entries()
    {
        if (this.root.entries.length == 0)
        {
            return new Entry[0];
        }

        return this.entries(this.root, this.height);
    }

    // Helper method to retrieve all entries present in the tree
    private Entries entries(Node* node, uint height)
    {
        if (height == 0)
        {
            Entries entries = [];
            auto currentNode = node;

            while (currentNode != null)
            {
                for (int i = 0; i < currentNode.n; i++)
                {
                    entries ~= currentNode.entries[i];
                }

                currentNode = currentNode.next;
            }

            return entries;
        }

        return entries(node.entries[0].child, height - 1);
    }

    /**
        Delete a `key` from the tree. This also removes the associated value.

        Params:
            key = the key to be removed from the tree.

        Returns:
            boolean. true if the key was found and deleted and false if the key was never found in the tree.
     */
    public bool remove(K key)
    {
        auto isRemoved = false;
        auto rebalance = false;
        this.remove(this.root, key, isRemoved, rebalance, this.height);

        // Update the height & root reference if necessary.
        if (this.root.n == 1)
        {
            auto oldRoot = this.root;
            this.root = this.root.entries[0].child;
            oldRoot.removeAt(0);
            oldRoot = null;

            this.height--;
        }
        return isRemoved;
    }

    private void remove(Node* node, K key, ref bool isRemoved, ref bool rebalance, uint height)
    {
        if (height == 0)
        {
            // Delete from the leaf node if value can be found
            auto index = BPtree.findIndexOf(node.entries, key, node.n);
            // Deleting from the leaf node marks isRemoved as true
            if (index >= 0)
            {
                if (node.removeAt(index))
                {
                    this.size--;
                    // Check if any tree-balancing rule has been violated.
                    // Is the number of entries less than the minimum required?
                    if (node.n < this.getMinimumNumberOfEntries())
                    {
                        rebalance = true;
                    }
                    // Indicate deletion occured
                    isRemoved = true;
                }
            }
            return;
        }
        // The index of the current node entry that we are visiting
        auto i = 0;

        for (i = 0; i < node.n; i++)
        {
            if (i + 1 < node.n)
            {
                if (key < node.entries[i + 1].key)
                {
                    break;
                }
            }
            else
            {
                break;
            }
        }

        // Keep searching
        this.remove(node.entries[i].child, key, isRemoved, rebalance, height - 1);

        // Deletion from internal nodes happens here. (can we reuse deletion from the leaf nodes? and make this recursive?)
        // Is the extra recursive call necessary? How many functions may we add to the call stack?
        // Deletion in index nodes can only be done if the key was found in the leaf node
        if (isRemoved)
        {
            // TODO: Borrowing should be done through the parent node.
            // If index != key being deleted, move index to the borrowing node and replace with the borrowed value.
            // else, replace both index and borrowing node values with borrowed value.
            // Consider the difference between the index & leaf nodes in this operation.
            if (rebalance)
            {
                auto predecessorIndex = (cast(int) i) - 1;
                auto successorIndex = (cast(int) i) + 1;
                // Try to borrow from the predecessor
                if (predecessorIndex >= 0 && node.childAt(predecessorIndex)
                    .canBeBorrowedFrom(height - 1))
                {
                    auto predecessorChildNode = node.childAt(predecessorIndex);
                    this.borrow(node, predecessorChildNode, i, predecessorChildNode.n - 1,
                        i, 0, height - 1);
                }
                else if (successorIndex < node.n && node.childAt(successorIndex)
                    .canBeBorrowedFrom(height - 1))
                {
                    auto successorChildNode = node.childAt(successorIndex);
                    this.borrow(node, successorChildNode, successorIndex, 0, i, node.childAt(i)
                            .n, height - 1);
                }
                else
                {
                    // Merge operation (Borrowing wasn't possible)
                    // Merge into the predecessor node
                    if (predecessorIndex >= 0)
                    {
                        auto predecessorChildNode = node.childAt(predecessorIndex);
                        predecessorChildNode.extendWithNode(node.childAt(i));
                        // Delete entries from current child node
                        // Delete node key
                        node.removeAt(i);
                    }
                    else
                    {
                        // Merge into the successor node
                        // In this case, instead of moving our nodes into the successor node, we move the successor node into the current node
                        // This way, we don't need to update the parent's key.
                        auto successorChildNode = node.childAt(successorIndex);
                        node.childAt(i).extendWithNode(successorChildNode);
                        node.removeAt(successorIndex);
                    }
                    // TODO: LeafMerge and IndexMerge
                }

                rebalance = false;
            }

            // Check if the node contains an index whose value matches the key to be deleted.
            auto index = BPtree.findIndexOf(node.entries, key, node.n);
            // Deleting from the leaf node marks isRemoved as true
            if (index >= 0)
            {
                // if (node.removeAt(index))
                // {
                // Check if any tree-balancing rule has been violated.
                // Is the number of entries less than the minimum required?
                if (node.n <= this.getMinimumNumberOfEntries())
                {
                    // If it's the root node, just replace the value with the minimum value from the
                    // right children.
                    if (height == this.getHeight())
                    {
                        if (node.n > 1)
                            node.setNodeKeyAt(0, node.childAt(1).min);
                    }
                    else
                    {
                        rebalance = true;
                    }

                }
                else
                {
                    // No rebalance needed; replace the deleted entry with the minimum value from the right child
                    node.setNodeKeyAt(index, node.childAt(index).min);
                }
                //}
            }
        }
    }

    /**
      The borrow operation used during the deletion process.

      Params:
        - parentNode: The parent node of the child node borrowing from its siblings.
        - siblingNode: The sibling node from which an entry will be borrowed.
        - sharedNodeIndex: The index of the shared node.
        - siblingEntryOfferIndex: The index of the entry to be borrowed from the sibling node.
        - childIndex: The index of the child node receiving the borrowed entry.
        - childEntryInsertionIndex: The index where the borrowed entry will be inserted in the child node.
        - height: The height of the child node being borrowed for where 0 means leaf node.
    */
    private void borrow(Node* parentNode, Node* siblingNode, uint sharedNodeIndex, uint siblingEntryOfferIndex,
        uint childIndex, uint childEntryInsertionIndex, uint height)
    {
        // The node with the maximum value in predecessor child node.
        auto borrowedEntry = siblingNode.offerEntryAt(
            siblingEntryOfferIndex)
            .get;
        // Insert the borrowed node into the child where the remove operation occurred.
        // Borrowing from the predecessor leads to inserting it at the beginning of the target child.
        parentNode.childAt(childIndex).insertAt(childEntryInsertionIndex, borrowedEntry);
        // Leaf node
        if (height == 0)
        {
            // Replace the index-value of the parent node index with the smallest value in the right suBPtree.
            // The child at index i is the right suBPtree.
            auto indexValue = parentNode.childAt(sharedNodeIndex).min;
            // Actual index/key replacement
            // We replace the value at the sibling index as that's the "shared-node" index
            parentNode.setNodeKeyAt(sharedNodeIndex, indexValue);
        }
        else
        {
            // For internal nodes, borrowing is done through the parent node.
            // The parent node key is updated to the key of the borrowed child.
            // The recipient node key is set to the parent node key
            auto borrowedChildKey = borrowedEntry.key;
            auto parentNodeKey = parentNode.keyAt(sharedNodeIndex);

            // Update the parent node key with the borrowed child key.
            parentNode.setNodeKeyAt(sharedNodeIndex, borrowedChildKey);
            // Update the recipient node key with the previous parent node key.
            borrowedEntry.setKey(parentNodeKey);
        }
    }

    /**
        Check if the B+Tree is empty.
    */
    public bool isEmpty()
    {
        return this.root == null || this.root.n == 0;
    }

    /**
        `Clear` the B+Tree. by setting the root to null.
    */
    public void clear()
    {
        this.root = new Node(0, this.ENTRIES_SIZE);
        this.size = 0;
        this.height = 0;
    }

    /*
        String representation of the B+Tree
    */
    override public string toString()
    {
        auto output_array = this.toString(this.root, this.height, "");
        auto inverted_BPtree_string = "";

        while (!output_array.empty)
        {
            inverted_BPtree_string ~= format("%s", output_array[$ - 1]);
            output_array = output_array[0 .. $ - 1];
        }
        return inverted_BPtree_string;
    }

    private string[] toString(Node* node, uint height, string indent)
    {
        string[] s;
        Entries children = node.entries;

        if (height == 0)
        {
            for (int j = 0; j < node.n; j++)
            {
                s ~= format("%s%s %s\n", indent, children[j].key, children[j].value);
            }
        }
        else
        {
            for (int j = 0; j < node.n; j++)
            {
                if (j > 0)
                {
                    s ~= format("%s(%s)\n", indent, children[j].key);
                }
                string newIndent = indent;
                newIndent ~= "\t";
                s ~= toString(children[j].child, height - 1, newIndent);
            }
        }

        return s;
    }

    /**
     * Enum definition of the different BinarySearch strategies
     */
    enum BinarySearchStrategy
    {
        // This is the default strategy. Returns the correct index when there's an
        // exact match for the value being searched for in an array. If the value is
        // missing, it returns -1
        EXACT_MATCH,

        // Returns the insertion position of a value in a sorted array. If the value
        // is already present, the index where the value is will be returned, otherwise
        // the index where the value would have been, had it been present, is returned.
        INSERTION_POSITION,
    }

    // Binary search implementation to find the index of a matching element based in Entries
    static int findIndexOf(K)(Entry[] entries, K key, int n,
        BinarySearchStrategy binarySearchStartegy = BinarySearchStrategy.EXACT_MATCH)
    {
        if (n == 0)
            return -1;

        int left = 0;
        int right = n - 1;

        while (left <= right)
        {
            auto mid = left + (right - left) / 2;

            if (entries[mid].key == key)
            {
                return mid;
            }

            if (entries[mid].key < key)
            {
                left = mid + 1;
            }
            else
            {
                right = mid - 1;
            }
        }

        if (binarySearchStartegy == BinarySearchStrategy.INSERTION_POSITION)
        {
            // The insertion index is at the beginning to the array.
            if (right < 0)
            {
                return 0;
            }

            // The insertion index is either within the array or the array needs to be grown.
            if (left > right)
            {
                return left;
            }
        }

        return -1;
    }

    static class InvalidArgumentException : Exception
    {
        this(string msg)
        {
            super(msg);
        }
    }
}

unittest
{
    import std.exception : assertThrown;

    auto tree = new BPtree!(uint, string)(2);
    // Upon initialization, the tree should be empty.
    assert(tree.isEmpty);
    assert(tree.getHeight == 0);
    assert(tree.getSize == 0);
    assert(tree.entries == []);
    assert(tree.keys == []);
    assert(tree.values == []);
    assert(tree.getMinimumDegree == 2);

    // Add elements to the tree.
    tree.put(3, "3");
    tree.put(2, "2");
    tree.put(9, "9");

    assert(!tree.isEmpty);
    assert(tree.getHeight == 0);
    assert(tree.getSize == 3);
    assert(tree.keys == [2, 3, 9]);
    assert(tree.values == ["2", "3", "9"]);

    // Add an element that results on the tree's height increasing.
    tree.put(15, "15");
    assert(tree.getHeight == 1); // Height increase from a node `split`
    assert(tree.getSize == 4);
    foreach (key; [2, 3, 9, 15])
    {
        assert(tree.get(key) == format("%s", key));
    }

    // `put` should also update the value of an existing key.
    assert(tree.get(3) == "3");
    tree.put(3, "45"); // Update the value of associated with key "3"
    assert(tree.get(3) == "45");
    assert(tree.keys == [2, 3, 9, 15]);
    assert(tree.values == ["2", "45", "9", "15"]);
    // Restore 3's value to "3"
    tree.put(3, "3");
    assert(tree.get(3) == "3");
    assert(tree.values == ["2", "3", "9", "15"]);

    // Add 4 more elements
    tree.put(16, "16");
    tree.put(17, "17");
    tree.put(0, "0");
    tree.put(1, "1");

    // Assert that inserted entries have matching values
    foreach (key; [0, 1, 2, 3, 9, 15, 16, 17])
    {
        assert(tree.get(key) == format("%s", key));
    }

    // The tree's height should now be 2
    assert(tree.getHeight == 2);
    assert(tree.getSize == 8);
    assert(tree.keys == [0, 1, 2, 3, 9, 15, 16, 17]);
    assert(tree.values == ["0", "1", "2", "3", "9", "15", "16", "17"]);
    auto treeStringValue =
        `		17 17
		16 16
	(16)
		15 15
		9 9
(9)
		3 3
		2 2
	(2)
		1 1
		0 0
`;
    assert(tree.toString == treeStringValue);

    // Get based on key ranges
    assert(tree.get(0, 2) == ["0", "1", "2"]);
    assert(tree.get(3, 15) == ["3", "9", "15"]);
    assert(tree.get(16, 20) == ["16", "17"]);
    assert(tree.get(18, 20) == []);

    // Get based on an array of keys
    assert(tree.get([0, 2, 3]) == ["0", "2", "3"]);
    assert(tree.get([9, 15, 16]) == ["9", "15", "16"]);
    assert(tree.get([17]) == ["17"]);
    assert(tree.get([18, 20]) == [Nullable!string.init, Nullable!string.init]);

    // Test on remove!
    assert(tree.contains(1));
    tree.remove(1);
    assert(!tree.contains(1));
    assert(tree.get(1).isNull);
    assert(tree.keys == [0, 2, 3, 9, 15, 16, 17]);
    assert(tree.values == ["0", "2", "3", "9", "15", "16", "17"]);
    assert(tree.getSize == 7);
    assert(tree.getHeight == 2); // The tree's height is still the same.

    assert(tree.contains(0));
    tree.remove(0);
    assert(!tree.contains(0));
    assert(tree.get(0).isNull);
    assert(tree.keys == [2, 3, 9, 15, 16, 17]);
    assert(tree.values == ["2", "3", "9", "15", "16", "17"]);
    assert(tree.getSize == 6);
    assert(tree.getHeight == 2); // The tree's height is still the same.

    assert(tree.contains(2));
    tree.remove(2);
    assert(!tree.contains(2));
    assert(tree.get(2).isNull);
    assert(tree.keys == [3, 9, 15, 16, 17]);
    assert(tree.values == ["3", "9", "15", "16", "17"]);
    assert(tree.getSize == 5);
    assert(tree.getHeight == 1); // The tree's height is reduced by 1 as merging is expected to have occured.
    assert(tree.entries == [
            BPtree!(uint, string).Entry(3, "3"),
            BPtree!(uint, string).Entry(9, "9"),
            BPtree!(uint, string).Entry(15, "15"),
            BPtree!(uint, string).Entry(16, "16"),
            BPtree!(uint, string).Entry(17, "17")
        ]);

    // `clear` method testing.
    tree.clear();
    foreach (key; [3, 9, 15, 16, 17])
    {
        assert(tree.get(key).isNull);
        assert(!tree.contains(key));
    }
    assert(tree.isEmpty);
    assert(tree.getHeight == 0);
    assert(tree.getSize == 0);
    assert(tree.entries == []);
    assert(tree.keys == []);
    assert(tree.values == []);
    assert(tree.toString == "");

    // An exception is thrown if the degree specified in less than 2.
    assertThrown!(BPtree!(uint, string).InvalidArgumentException)(new BPtree!(uint, string)(1));

    // Assert that the size increases and an entry is added when the first entry to be inserted
    // has a key equivalent to the default Entry key.
    auto tree2 = new BPtree!(uint, uint)(2);
    assert(tree2.isEmpty);
    assert(tree2.getSize == 0);
    assert(tree2.entries == []);
    assert(tree2.keys == []);
    assert(tree2.values == []);
    // The default Entry is (Entry(key = 0, value = 0, child = null))
    tree2.put(0, 0);
    assert(!tree2.isEmpty);
    assert(tree2.getSize == 1);
    assert(tree2.entries == [BPtree!(uint, uint).Entry.init]);
    assert(tree2.keys == [0]);
    assert(tree2.values == [0]);
    tree2.clear();
}
