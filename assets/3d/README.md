# 3D Models Directory

Place your home's 3D model here.

## Recommended Format

**File**: `home_model.glb` (glTF Binary format)

## How to Create Your Home Model

### Option 1: Export from CAD/SolidWorks

1. **Export from your CAD software**:
   - File > Export > STL or OBJ format
   - Include all rooms and sections

2. **Convert to glTF using Blender**:
   ```
   1. Open Blender
   2. File > Import > STL/OBJ
   3. Name each room mesh:
      - living_room
      - kitchen
      - bedroom
      - garage
      - bathroom
      etc.
   4. Simplify geometry (optional):
      - Select mesh > Modifiers > Decimate
      - Adjust ratio for file size
   5. File > Export > glTF 2.0
   6. Format: glTF Binary (.glb)
   7. Save as: home_model.glb
   ```

3. **Place the file here**: `assets/3d/home_model.glb`

4. **Update the HTML file**:
   - Open `assets/web/home_visualization.html`
   - Uncomment the GLTFLoader section (around line 78)
   - Comment out the `createPlaceholderHouse()` call

### Option 2: Use Online Converter

1. Upload your CAD file to: https://products.aspose.app/3d/conversion
2. Convert to glTF format
3. Download and save as `home_model.glb`
4. Place in this directory

### Option 3: Create Simple Model in Blender

1. Open Blender
2. Create basic room shapes with cubes
3. Name each object with room names
4. Export as glTF Binary
5. Place here

## Room Naming Convention

Your room meshes should be named to match the location of your devices:

```
living_room
kitchen
bedroom
bedroom_master
bedroom_guest
bathroom
bathroom_main
garage
hallway
entrance
office
dining_room
basement
attic
```

These names will be used to:
- Highlight rooms when alarms occur
- Identify which room was tapped for control
- Map devices to physical locations

## File Size Recommendations

- **Optimal**: Under 5 MB
- **Maximum**: 20 MB
- **Tips to reduce size**:
  - Use decimation in Blender
  - Remove unnecessary details
  - Optimize textures (or remove them)
  - Combine similar meshes

## Testing Your Model

1. Place `home_model.glb` in this directory
2. Update `assets/web/home_visualization.html` (uncomment GLTFLoader)
3. Run the app: `flutter run`
4. Navigate to the "Home View" tab
5. You should see your 3D model

## Placeholder Model

If you don't have a 3D model yet, the app includes a placeholder house with:
- Living Room (blue)
- Kitchen (yellow)
- Bedroom (purple)
- Garage (grey)

This allows you to test the visualization features before adding your actual home model.

## Troubleshooting

**Model doesn't load:**
- Check file is named exactly `home_model.glb`
- Verify file is valid glTF (test in https://gltf-viewer.donmccurdy.com/)
- Check browser console in WebView for errors
- Ensure pubspec.yaml includes this directory in assets

**Model loads but is too big/small:**
- Adjust camera position in `home_visualization.html`
- Scale the model in Blender before export

**Rooms don't respond to taps:**
- Verify mesh names match exactly (case-sensitive)
- Check JavaScript console for raycasting issues
- Ensure meshes are not nested in complex hierarchies

---

**No 3D model?** No problem! The app works perfectly with the placeholder house. Add your actual model whenever you're ready.
