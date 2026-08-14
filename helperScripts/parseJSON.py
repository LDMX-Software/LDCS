import argparse
import json


def clean_value(value):
    #don't have empty values in the flat record 
    if value == "" or value == []:
        return "None"
    if isinstance(value, str):
        # Remove any namespace prefix like ldmx:: etc.
        return value.split("::")[-1]
    return value


def get_label_parts(item, preferred_keys):
    if not isinstance(item, dict):
        return []
    parts = []
    for key in preferred_keys:
        if key in item and item[key] not in ("", [], None):
            cleaned = str(clean_value(item[key]))
            if cleaned not in parts:
                parts.append(cleaned)
    return parts


def build_adaptive_labels(items, preferred_keys, max_parts=3):
    """
    Build a minimally specific unique label for each dict item in a sibling list.
    Example:
      - unique className -> "Foo"
      - repeated className -> "Foo.Bar"
      - still repeated -> "Foo.Bar.Baz"
    Non-dict items get None.
    """
    parts_per_item = [get_label_parts(item, preferred_keys) for item in items]
    labels = [None] * len(items)
    for i, parts in enumerate(parts_per_item):
        if not parts:
            continue
        for n in range(1, min(len(parts), max_parts) + 1):
            candidate = ".".join(parts[:n])
            collisions = 0
            for other_parts in parts_per_item:
                if not other_parts:
                    continue
                if len(other_parts) >= n and ".".join(other_parts[:n]) == candidate:
                    collisions += 1
            if collisions == 1:
                labels[i] = candidate
                break

    return labels

# recursive function to trickle through json tree of all parameters 
def flatten_json(obj, prefix="", preferred_keys=None, result=None):
    # the values of these parameters can be used to create keys for disambiguation
    if preferred_keys is None:
        preferred_keys = [
            "className", "class_name",
            "object_name", "objectName",
            "instanceName", "instance_name",
            "name", "id",
        ]
    if result is None:
        result = {}
    if isinstance(obj, dict):
        for key, value in obj.items():
            # Drop "sequence" etc generic identifiers from the key
            if key in ("sequence", "entries", "actions", "inputMeta"):
                new_prefix = prefix
            else:
                new_prefix = f"{prefix}.{key}" if prefix else key
            flatten_json(value, new_prefix, preferred_keys, result)
        return result
    elif isinstance(obj, list):
        if len(obj) == 0:
            result[prefix] = "None"
            return result
        if all(not isinstance(x, (dict, list)) for x in obj):
            if len(obj) == 1:
                result[prefix] = clean_value(obj[0])
            else:
                result[prefix] = [clean_value(x) for x in obj]
            return result
        if len(obj) == 1:
            flatten_json(obj[0], prefix, preferred_keys, result)
            return result
        labels = build_adaptive_labels(obj, preferred_keys, max_parts=3)
        for i, value in enumerate(obj):
            label = labels[i]
            if label is not None:
                new_prefix = f"{prefix}.{label}" if prefix else label
            else:
                new_prefix = f"{prefix}[{i}]" if prefix else f"[{i}]"
            flatten_json(value, new_prefix, preferred_keys, result)
        return result
    else:
        result[prefix] = clean_value(obj)
        return result


def make_record(new_flat, ref_flat=None, ref_name=None):
    '''
    
    '''
    if new_flat is None:
        raise ValueError("new_flat is None; flatten_json() did not return a dictionary")
    if ref_flat is None:
        record = dict(new_flat)
    else:
        record = {}
        # only keep lines that don't match the reference metadata
        for key, value in new_flat.items():
            if key not in ref_flat or ref_flat[key] != value:
                record[key] = value
    if ref_flat is not None and ref_name is not None and record:
        record["reference_file"] = ref_name
    return record


def load_json_file(path):
    with open(path, "r") as f:
        return json.load(f)


def load_flat_record(path):
    with open(path, "r") as f:
        return json.load(f)


def write_record(record, output_path):
    with open(output_path, "w") as f:
        json.dump(record, f, indent=2, sort_keys=True)


def print_record(record):
    for key, value in record.items():
        print(f"{key}={value}")

        
# helper functions to handle both file json and dicts 
def normalize_new_input(new_input):
    """
    Accept either:
      - dict: raw nested JSON already in memory
      - str: path to raw JSON file
    Return raw nested JSON as dict.
    """
    if isinstance(new_input, dict):
        return new_input

    if isinstance(new_input, str):
        return load_json_file(new_input)

    raise TypeError("new_input must be a dict or a JSON file path")


def normalize_ref_input(ref_input):
    """
    Accept either:
      - None
      - dict: already-flattened reference record in memory
      - str: path to flattened reference record file
    Return flattened reference dict or None.
    """
    if ref_input is None:
        return None

    if isinstance(ref_input, dict):
        return ref_input

    if isinstance(ref_input, str):
        return load_flat_record(ref_input)

    raise TypeError("ref_input must be None, a dict, or a flat-record file path")



def build_record_from_inputs(new_input, ref_input=None, ref_name=None, preferred_keys=None):
    """
    new_input:
      - raw nested JSON dict
      - or path to raw JSON file

    ref_input:
      - None
      - flattened reference dict
      - or path to flattened reference record file
    """
    new_data = normalize_new_input(new_input)
    new_flat = flatten_json(new_data, preferred_keys=preferred_keys)

    ref_flat = normalize_ref_input(ref_input)

    # infer ref name from input json file if not set --> USE ONLY FOR DEBUGGING
    # in production, we want the reference file to be the .root file findable
    # in rucio, not a transient json file name 
    if ref_name is None and isinstance(ref_input, str):
        ref_name = os.path.basename(ref_input)
    
    return make_record(new_flat, ref_flat=ref_flat, ref_name=ref_name)

      
# redundant function that can be used to print diff to screen 
def compare_json_files(new_content, ref_content, ref_name):
    new_flat = flatten_json(new_content)
    ref_flat = flatten_json(ref_content)

    for key, new_value in new_flat.items():
        if key not in ref_flat or ref_flat[key] != new_value:
            print(f"{key}={new_value}    [reference={ref_name}]")
            

            

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Flatten JSON / create delta record")
    parser.add_argument("-m", "--metaDump", default="parameterDump.json", help="Parameter dump JSON file")
    parser.add_argument("--ref-record", help="Existing flattened reference record")
    parser.add_argument("--ref-name", help="Reference file name to store in output")
    parser.add_argument("--output", help="Output record file")
    args = parser.parse_args()

    record = build_record_from_inputs(
        new_input=args.metaDump,
        ref_input=args.ref_record,
        ref_name=args.ref_name,
    )

    print_record(record)

    if args.output:
        write_record(record, args.output)


    
