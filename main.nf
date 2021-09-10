#!/usr/bin/env nextflow

params.outdir = '.'
params.input = '/home/ubuntu/htan-dcc-image-prep/test_data/*.ome.tif'
params.miniature = false


Channel
  .fromPath(params.input)
  .into {input_ch_ome; input_ch_notome; view_ch}

view_ch.view()

input_ch_ome
  .branch {
      ome: it =~ /.+\.ome\.tif{1,2}$/
      other: true
    }
    .set { input_groups }

input_groups.ome
  .map { file -> tuple(file.simpleName, file) }
  .into {ome_ch; ome_view_ch}

ome_view_ch.view { "$it is an ometiff" }

input_groups.other
  .map { file -> tuple(file.simpleName, file) }
  .into {bf_convert_ch; bf_view_ch}

bf_view_ch.view { "$it is NOT an ometiff" }

process make_ometiff{
  errorStrategy 'ignore'
//  conda '/home/ubuntu/anaconda3/envs/auto-minerva-author'
  input:
    set name, file(input) from bf_convert_ch

  output:
    set name, file("${name}.ome.tiff") into converted_ch

  script:
  """
  bioformats2raw $input 'raw_dir'
  raw2ometiff 'raw_dir' "${name}.ome.tiff"
  """
}

ome_ch
  .mix(converted_ch)
  .into { ome_story_ch; ome_pyramid_ch; ome_miniature_ch }

process make_story{
  errorStrategy 'ignore'
//  conda '/home/ubuntu/anaconda3/envs/auto-minerva-author'
  publishDir "$params.outdir", saveAs: {filname -> "$name/story.json"}
  echo true
  input:
    set name, file(ome) from ome_story_ch
  output:
    set name, file('story.json') into story_ch
  """
  python $projectDir/auto-minerva/story.py $ome > 'story.json'
  """
}

process render_pyramid{
  errorStrategy 'ignore'
  publishDir "$params.outdir", saveAs: {filname -> "$name/minerva-story"}
  echo true
//  conda '/home/ubuntu/anaconda3/envs/auto-minerva-author'
  input:
    set name, file(ome) from ome_pyramid_ch
    set story_name, file(story) from story_ch
  output:
    file '*'

    """
    python  $projectDir/minerva-author/src/save_exhibit_pyramid.py $ome $story 'minerva'
    cp $projectDir/resources/index.html minerva
    """
}

process render_miniature{
  errorStrategy 'ignore'
  publishDir "$params.outdir", saveAs: {filname -> "$name/miniature.png"}
  echo true
//  conda '/home/ubuntu/anaconda3/envs/miniature'
  when:
    params.miniature == true
  input:
    set name, file(ome) from ome_miniature_ch
  output:
    file 'data/*'

    """
    mkdir data
    python  $projectDir/miniature/docker/paint_miniature.py $ome 'miniature.png'
    """
}
